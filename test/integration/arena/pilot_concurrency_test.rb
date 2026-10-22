require "test_helper"
require "timeout"
require_relative "../../support/arena_foundation_helpers"

class ArenaPilotConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  include ArenaFoundationHelpers

  setup do
    @users = Array.new(3) { arena_user }
    @host, @student, @second = @users
    arena_grant(@host)
    content = Arena::Catalog.create_preview!
    @room = Arena::Game.create!(actor: @host, content_version: content, title: "Concurrent", question_count: 2, duration_seconds: 30, technical_preview: true)
    [@student, @second].each { |user| Arena::Join.call(actor: user, code: Arena::Invites.code(@room), nickname: "Aluno") }
    command("start")
  end

  teardown { @users.each { |user| user.destroy! if User.exists?(user.id) } }

  def command(name)
    Arena::Game.command!(actor: @host, session: @room, command: name, expected_version: @room.reload.lock_version)
  end

  def race(*operations)
    ready, release = Queue.new, Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          release.pop
          begin
            operation.call
          rescue Arena::Conflict, Arena::InvalidAnswer, Arena::Unavailable, Arena::RateLimited => error
            error.class
          end
        end
      end
    end
    pids = operations.map { Timeout.timeout(5) { ready.pop } }
    assert_equal operations.size, pids.uniq.size
    operations.size.times { release << true }
    threads.map { |thread| Timeout.timeout(10) { thread.value } }
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
  end

  test "answer versus close persists once and releases only a single result" do
    round = @room.arena_rounds.find_by!(state: "answering")
    option = round.arena_question_snapshot.payload.fetch("correct_option_id")
    version = @room.lock_version
    race(-> { Arena::RecordAnswer.call(actor: User.find(@student.id), round: ArenaRound.find(round.id), option_id: option, idempotency_key: SecureRandom.uuid) },
      -> { Arena::Game.command!(actor: User.find(@host.id), session: ArenaSession.find(@room.id), command: "close", expected_version: version) })
    command("close") if round.reload.state == "answering"
    assert_equal "results", round.reload.state
    assert_operator ArenaAnswer.where(arena_round: round).count, :<=, 1
    assert_equal 1, @room.arena_events.where(arena_round: round, payload: { "state" => "results" }).count
    expected = ArenaAnswer.where(arena_round: round).exists? ? 1000 : 0
    assert_equal expected, Arena::Scoreboard.rows(@room).find { |row| row[:membership_id] == @room.arena_memberships.find_by!(user: @student).id }[:points]
  end

  test "double next opens exactly one new round" do
    command("close")
    version = @room.reload.lock_version
    results = race(*Array.new(2) { -> { Arena::Game.command!(actor: User.find(@host.id), session: ArenaSession.find(@room.id), command: "next", expected_version: version) } })
    assert_equal 1, results.count(Arena::Conflict)
    assert_equal 1, @room.arena_rounds.where(state: "answering").count
    assert_equal 2, @room.arena_rounds.find_by!(state: "answering").position
  end

  test "expired pause closes instead of reopening an elapsed window and settlement is idempotent" do
    round = @room.arena_rounds.find_by!(state: "answering")
    round.update_columns(answer_open_at: 2.minutes.ago, deadline_at: 1.minute.ago)
    command("pause")
    assert_equal "results", round.reload.state
    command("resume")
    sequence = @room.reload.event_sequence
    2.times { Arena::Game.settle!(actor: @student, session: @room) }
    assert_equal sequence, @room.reload.event_sequence
    assert_equal "results", round.reload.state
  end

  test "simultaneous rate limit consumes only its remaining budget despite outer rollback" do
    principal = SecureRandom.uuid
    ArenaSession.transaction do
      Arena::RateLimit.consume!(scope: "regression", subject: principal, limit: 2)
      raise ActiveRecord::Rollback
    end
    results = race(*Array.new(2) { -> { Arena::RateLimit.consume!(scope: "regression", subject: principal, limit: 2) } })
    assert_equal 1, results.count(true)
    assert_equal 1, results.count(Arena::RateLimited)
  end

  test "ties share a position and do not use response time as a tiebreaker" do
    command("close")
    assert_equal [1, 1], Arena::Scoreboard.rows(@room).map { |row| row[:place] }
  end

  test "only one entrant obtains the last available place under concurrency" do
    lobby = Arena::Game.create!(actor: @host, content_version: @room.arena_content_version, title: "Capacity", question_count: 1, duration_seconds: 30, technical_preview: true)
    code = Arena::Invites.code(lobby)
    39.times do
      user = arena_user
      @users << user
      Arena::Join.call(actor: user, code: code, nickname: "Participante")
    end
    candidates = Array.new(2) { arena_user }
    @users.concat(candidates)
    results = race(*candidates.map { |candidate| -> { Arena::Join.call(actor: User.find(candidate.id), code: code, nickname: "Última vaga") } })
    assert_equal 1, results.count(Arena::Unavailable)
    assert_equal 1, results.count { |result| result.is_a?(ArenaMembership) }
    assert_equal 40, lobby.arena_memberships.where(status: "active").count
  end

  test "rate limiting works when every application connection is already leased" do
    # The main test owns one connection; each worker holds another, as Devise
    # does during an authenticated request. No spare pool slot is available.
    workers = ActiveRecord::Base.connection_pool.size - 1
    operations = Array.new(workers) { -> { Arena::RateLimit.consume!(scope: "pool-saturation", subject: SecureRandom.uuid, limit: 1) } }
    results = race(*operations)
    assert_equal workers, results.count(true)
  end

  test "rate limit windows are identical across connection time zones" do
    principal = SecureRandom.uuid
    connection = ActiveRecord::Base.connection
    previous_zone = connection.select_value("SHOW TIME ZONE")
    connection.execute("SET TIME ZONE 'America/Sao_Paulo'")
    assert Arena::RateLimit.consume!(scope: "time-zone", subject: principal, limit: 1)
    connection.execute("SET TIME ZONE 'UTC'")
    assert_raises(Arena::RateLimited) do
      Arena::RateLimit.consume!(scope: "time-zone", subject: principal, limit: 1)
    end
  ensure
    connection&.execute("SET TIME ZONE #{connection.quote(previous_zone)}") if previous_zone
  end
end
