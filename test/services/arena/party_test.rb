require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"

class ArenaPartyTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers

  setup do
    @host, @student = arena_user, arena_user
    @content = Arena::Catalog.create_preview!
    @now = Time.current
  end

  def party(count: 3)
    Arena::Game.create!(actor: @host, content_version: @content, title: "Jogo com amigos", question_count: count,
      duration_seconds: 30, technical_preview: true, experience: "party", host_nickname: "Maestro")
  end

  def at(time = @now, &block)
    Arena::DatabaseClock.stub(:now, time, &block)
  end

  def command(room, name)
    at { Arena::Game.command!(actor: @host, session: room, command: name, expected_version: room.reload.lock_version) }
  end

  def settle(room)
    at { Arena::Game.settle!(actor: @student, session: room) }
  end

  test "host plays three questions and the game reaches a shared podium without manual next" do
    room = at { party }
    Arena::Join.call(actor: @student, code: Arena::Invites.code(room), nickname: "Sabiá")
    assert_equal 2, room.arena_memberships.count
    before = [StudyActivity.count, StudyActivity.sum(:xp_earned)]
    command(room, "start")
    replay = nil
    3.times do |index|
      round = room.arena_rounds.find_by!(position: index + 1)
      assert_equal "ready", round.state
      state = at { Arena::SessionView.call(actor: @host, session: room) }
      assert state[:participant]
      assert_equal "countdown", state[:phase]
      assert_nil state.dig(:round, :question)
      refute state.dig(:round, :can_answer)
      @now = round.answer_open_at
      settle(room)
      assert_equal "answering", round.reload.state
      correct = round.arena_question_snapshot.payload.fetch("correct_option_id")
      [@host, @student].each do |user|
        key = SecureRandom.uuid
        ack = at { Arena::RecordAnswer.call(actor: user, round: round, option_id: correct, idempotency_key: key) }
        replay ||= [round, correct, key, ack]
        refute_match(/correct|points/, ack.to_json)
      end
      settle(room)
      assert_equal "results", round.reload.state
      assert_equal @now + 5.seconds, round.advance_at
      @now += 4.seconds
      settle(room)
      assert_equal "results", round.reload.state
      @now += 1.second
      settle(room)
    end
    assert_equal "completed", room.reload.state
    state = at { Arena::SessionView.call(actor: @student, session: room) }
    assert_equal 3000, state.dig(:own_result, :points)
    assert_equal [1, 1], state.fetch(:podium).map { |row| row[:place] }
    refute_match(/membership_id|user_id|@example.test/, state.fetch(:podium).to_json)
    assert_equal before, [StudyActivity.count, StudyActivity.sum(:xp_earned)]
    old_round, option, key, ack = replay
    assert_no_difference "ArenaAnswer.count" do
      assert_equal ack, at { Arena::RecordAnswer.call(actor: @host, round: old_round, option_id: option, idempotency_key: key) }
    end
    assert_raises(Arena::Forbidden) { Arena::SessionView.call(actor: arena_user, session: room) }
  end

  test "party can be played alone while a missing answer waits for the database deadline" do
    room = at { party(count: 1) }
    command(room, "start")
    round = room.arena_rounds.sole
    @now = round.answer_open_at
    at { Arena::Game.settle!(actor: @host, session: room) }
    at { Arena::Game.settle!(actor: @host, session: room) }
    assert_equal "answering", round.reload.state
    @now = round.deadline_at
    at { Arena::Game.settle!(actor: @host, session: room) }
    assert_equal "results", round.reload.state
    @now = round.advance_at
    at { Arena::Game.settle!(actor: @host, session: room) }
    assert_equal "completed", room.reload.state
    assert_equal 0, Arena::Scoreboard.rows(room).sole[:points]
  end

  test "pause preserves countdown and feedback time without reopening an answered round" do
    room = at { party(count: 1) }
    command(room, "start")
    round = room.arena_rounds.sole
    @now += 1.second
    command(room, "pause")
    assert_equal "ready", round.reload.paused_from
    @now += 1.hour
    at { Arena::Game.settle!(actor: @host, session: room) }
    assert_equal "paused", room.reload.state
    command(room, "resume")
    assert_in_delta 2, round.reload.answer_open_at - @now, 0.001
    @now = round.answer_open_at
    at { Arena::Game.settle!(actor: @host, session: room) }
    option = round.arena_question_snapshot.payload.fetch("correct_option_id")
    at { Arena::RecordAnswer.call(actor: @host, round: round, option_id: option, idempotency_key: SecureRandom.uuid) }
    at { Arena::Game.settle!(actor: @host, session: room) }
    @now += 2.seconds
    command(room, "pause")
    assert_equal "results", round.reload.state
    assert_nil round.advance_at
    @now += 1.hour
    at { Arena::Game.settle!(actor: @host, session: room) }
    assert_equal "paused", room.reload.state
    command(room, "resume")
    assert_in_delta 3, round.reload.advance_at - @now, 0.001
    @now = round.advance_at
    at { Arena::Game.settle!(actor: @host, session: room) }
    assert_equal "completed", room.reload.state
    assert_equal 1, ArenaAnswer.where(arena_round: round).count
  end

  test "rematch is a fresh idempotent room without copying other players or changing history" do
    Arena::Catalog.publish!(content: @content, reviewer_reference: SecureRandom.uuid)
    room = at { party(count: 1) }
    command(room, "start")
    round = room.arena_rounds.sole
    @now = round.answer_open_at
    at { Arena::Game.settle!(actor: @host, session: room) }
    @now = round.reload.deadline_at
    at { Arena::Game.settle!(actor: @host, session: room) }
    @now = round.reload.advance_at
    at { Arena::Game.settle!(actor: @host, session: room) }
    version = room.reload.lock_version
    next_room = at { Arena::Game.rematch!(actor: @host, session: room, expected_version: version) }
    assert_equal next_room.id, at { Arena::Game.rematch!(actor: @host, session: room.reload, expected_version: version) }.id
    assert_not_equal room.id, next_room.id
    assert_not_equal room.invite_digest, next_room.invite_digest
    assert_equal "lobby_open", next_room.state
    assert_equal 1, next_room.arena_memberships.count
    assert_equal "completed", room.reload.state
    assert_equal next_room.id, room.rematch_session_id
    assert_raises(Arena::Forbidden) { Arena::Game.rematch!(actor: @student, session: room, expected_version: room.lock_version) }
  end
end
