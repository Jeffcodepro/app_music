require "test_helper"
require "timeout"
require_relative "../../support/arena_foundation_helpers"

class ArenaPartyConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  include ArenaFoundationHelpers

  setup do
    @host, @student = arena_user, arena_user
    reference = Arena::Catalog.create_preview!
    @content = ArenaContentVersion.create!(code: "party-race-#{SecureRandom.hex(8)}", revision: 1, title: "Referência de concorrência",
      status: "published", body: reference.body, content_digest: reference.content_digest, source_digest: reference.source_digest,
      reviewer_reference: SecureRandom.uuid, reviewed_at: Time.current)
    @room = Arena::Game.create!(actor: @host, content_version: @content, title: "Corrida", question_count: 2,
      duration_seconds: 30, technical_preview: true, experience: "party", host_nickname: "Maestro")
    Arena::Join.call(actor: @student, code: Arena::Invites.code(@room), nickname: "Sabiá")
    command("start")
  end

  teardown { [@student,@host].each { |user| user.destroy! if User.exists?(user.id) } }

  def command(name)
    Arena::Game.command!(actor: @host, session: @room, command: name, expected_version: @room.reload.lock_version)
  end

  def open_window
    round = @room.arena_rounds.find_by!(state: "ready")
    round.update!(answer_open_at: 1.second.ago, deadline_at: 1.minute.from_now)
    Arena::Game.settle!(actor: @host, session: @room)
    round.reload
  end

  def race(*operations)
    ready,release = Queue.new,Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          release.pop
          begin
            operation.call
          rescue Arena::Forbidden, Arena::InvalidAnswer, Arena::Conflict => error
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

  test "last answers and concurrent reconciliation produce one result and one next question" do
    round = open_window
    option = round.arena_question_snapshot.payload.fetch("correct_option_id")
    race(*[@host,@student].map { |user| -> { Arena::RecordAnswer.call(actor: User.find(user.id), round: ArenaRound.find(round.id), option_id: option, idempotency_key: SecureRandom.uuid) } })
    race(*[@host,@student].map { |user| -> { Arena::Game.settle!(actor: User.find(user.id), session: ArenaSession.find(@room.id)) } })
    assert_equal "results", round.reload.state
    assert_equal 1, @room.arena_events.where(arena_round: round, payload: { "state" => "results" }).count
    assert_equal 2, ArenaAnswer.where(arena_round: round).count
    round.update!(advance_at: 1.second.ago)
    race(*[@host,@student].map { |user| -> { Arena::Game.settle!(actor: User.find(user.id), session: ArenaSession.find(@room.id)) } })
    assert_equal 1, @room.arena_rounds.where(state: "ready").count
    assert_equal 2, @room.arena_rounds.find_by!(state: "ready").position
    assert_equal [1000,1000], Arena::Scoreboard.rows(@room).map { |row| row[:points] }
  end

  test "concurrent rematch creates one successor even with the original request version" do
    2.times do
      round = open_window
      command("close")
      round.reload.update!(advance_at: 1.second.ago)
      Arena::Game.settle!(actor: @host, session: @room)
    end
    assert_equal "completed", @room.reload.state
    version = @room.lock_version
    before = ArenaSession.uncached { ArenaSession.count }
    results = race(*Array.new(2) { -> { Arena::Game.rematch!(actor: User.find(@host.id), session: ArenaSession.find(@room.id), expected_version: version) } })
    assert_equal 1, results.map(&:id).uniq.size
    assert_equal before + 1, ArenaSession.uncached { ArenaSession.count }
    assert_equal results.first.id, @room.reload.rematch_session_id
  end

  test "removing a playing host closes and anonymizes while a guest is answering" do
    round = open_window
    option = round.arena_question_snapshot.payload.fetch("correct_option_id")
    results = race(-> { User.find(@host.id).destroy!; :removed },
      -> { Arena::RecordAnswer.call(actor: User.find(@student.id), round: ArenaRound.find(round.id), option_id: option, idempotency_key: SecureRandom.uuid) })
    assert_includes results, :removed
    assert_equal "cancelled", @room.reload.state
    assert_nil @room.host_id
    own_membership = @room.arena_memberships.find_by!(user_id: nil)
    assert_equal "Participante removido", own_membership.nickname
    assert_operator ArenaAnswer.where(arena_round: round).count, :<=, 1
  end

  test "last answer competing with settlement and manual close records one result" do
    round = open_window
    option = round.arena_question_snapshot.payload.fetch("correct_option_id")
    Arena::RecordAnswer.call(actor: @host, round: round, option_id: option, idempotency_key: SecureRandom.uuid)
    version = @room.reload.lock_version
    race(-> { Arena::RecordAnswer.call(actor: User.find(@student.id), round: ArenaRound.find(round.id), option_id: option, idempotency_key: SecureRandom.uuid) },
      -> { Arena::Game.settle!(actor: User.find(@host.id), session: ArenaSession.find(@room.id)) },
      -> { Arena::Game.command!(actor: User.find(@host.id), session: ArenaSession.find(@room.id), command: "close", expected_version: version) })
    Arena::Game.settle!(actor: @host, session: @room)
    assert_equal "results", round.reload.state
    assert_equal 1, @room.arena_events.where(arena_round: round, payload: { "state" => "results" }).count
    assert_includes [1,2], ArenaAnswer.where(arena_round: round).count
  end

  test "automatic advance racing a manual next opens one next question" do
    round = open_window
    command("close")
    round.reload.update!(advance_at: 1.second.ago)
    version = @room.reload.lock_version
    race(-> { Arena::Game.settle!(actor: User.find(@student.id), session: ArenaSession.find(@room.id)) },
      -> { Arena::Game.command!(actor: User.find(@host.id), session: ArenaSession.find(@room.id), command: "next", expected_version: version) })
    assert_equal 1, @room.arena_rounds.where(state: "ready").count
    next_round = @room.arena_rounds.find_by!(position: 2)
    assert_equal "ready", next_round.state
    assert_equal 1, @room.arena_events.where(arena_round: next_round, payload: { "state" => "ready" }).count
  end
end
