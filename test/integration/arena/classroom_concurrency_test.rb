require "test_helper"
require "timeout"
require_relative "../../support/arena_foundation_helpers"

class ArenaClassroomConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  include ArenaFoundationHelpers
  setup do
    @host,@student = arena_user,arena_user
    @room = Arena::Game.create!(actor: @host, content_version: Arena::Catalog.create_preview!, title: "Condução concorrente", question_count: 2,
      duration_seconds: 30, technical_preview: true, experience: "party", host_nickname: "Maestro", scoring_version: Arena::Scoring::CURRENT)
    @member = Arena::Join.call(actor: @student, code: Arena::Invites.code(@room), nickname: "Sabiá")
    Arena::Game.command!(actor: @host, session: @room, command: "start", expected_version: @room.reload.lock_version)
    @round = @room.arena_rounds.find_by!(position: 1)
    @round.update!(answer_open_at: 1.second.ago, deadline_at: 30.seconds.from_now)
    Arena::Game.settle!(actor: @host, session: @room)
    @option = @round.arena_question_snapshot.payload.fetch("correct_option_id")
  end
  teardown { [@student,@host].each { |user| user.destroy! if User.exists?(user.id) } }

  def race(*operations)
    ready,release = Queue.new,Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          release.pop
          begin
            operation.call
          rescue Arena::Forbidden, Arena::Conflict, Arena::InvalidTransition, Arena::InvalidAnswer => error
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

  def finish
    Arena::Game.command!(actor: @host, session: @room, command: "finish", expected_version: @room.reload.lock_version)
  end

  test "leave racing an answer keeps at most one accepted response and never loses accepted credit" do
    race(-> { Arena::Lobby.leave!(actor: User.find(@student.id), session: ArenaSession.find(@room.id)) },
      -> { Arena::RecordAnswer.call(actor: User.find(@student.id), round: ArenaRound.find(@round.id), option_id: @option, idempotency_key: SecureRandom.uuid) })
    assert_equal "left", @member.reload.status
    answers = ArenaAnswer.where(arena_membership: @member)
    assert_operator answers.count, :<=, 1
    finish
    row = Arena::Scoreboard.rows(@room).find { |item| item[:membership_id] == @member.id }
    assert_equal answers.count, row[:correct]
    assert_equal (answers.any? ? 1 : 0), row[:points].positive? ? 1 : 0
  end

  test "two leave requests make one state event" do
    before = @room.reload.event_sequence
    race(*Array.new(2) { -> { Arena::Lobby.leave!(actor: User.find(@student.id), session: ArenaSession.find(@room.id)) } })
    assert_equal before + 1, @room.reload.event_sequence
    assert_equal "left", @member.reload.status
  end

  test "finish racing settlement preserves one result and creates no next question" do
    Arena::RecordAnswer.call(actor: @student, round: @round, option_id: @option, idempotency_key: SecureRandom.uuid)
    version = @room.reload.lock_version
    race(-> { Arena::Game.command!(actor: User.find(@host.id), session: ArenaSession.find(@room.id), command: "finish", expected_version: version) },
      -> { Arena::Game.settle!(actor: User.find(@student.id), session: ArenaSession.find(@room.id)) })
    assert_equal "completed", @room.reload.state
    assert_equal "results", @round.reload.state
    assert_equal 1, @room.arena_events.where(arena_round: @round, payload: { "state" => "results" }).count
    assert_equal "void", @room.arena_rounds.find_by!(position: 2).state
    assert_equal 1, ArenaAnswer.where(arena_round: @round).count
  end
end
