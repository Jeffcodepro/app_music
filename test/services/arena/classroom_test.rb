require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"

class ArenaClassroomTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers

  setup do
    @host,@student,@other = arena_user,arena_user,arena_user
    @room = Arena::Game.create!(actor: @host, content_version: Arena::Catalog.create_preview!, title: "Aula em jogo",
      question_count: 3, duration_seconds: 30, technical_preview: true, experience: "party", host_nickname: "Maestro")
    @member = Arena::Join.call(actor: @student, code: Arena::Invites.code(@room), nickname: "Sabiá", avatar_id: "cat")
    @now = Time.current
  end

  def at(&block) = Arena::DatabaseClock.stub(:now, @now, &block)
  def command(name, actor: @host)
    at { Arena::Game.command!(actor: actor, session: @room, command: name, expected_version: @room.reload.lock_version) }
  end
  def open_question
    command("start")
    round = @room.arena_rounds.find_by!(position: 1)
    @now = round.answer_open_at
    at { Arena::Game.settle!(actor: @host, session: @room) }
    round.reload
  end
  def answer(round, actor: @student, right: true)
    payload = round.arena_question_snapshot.payload
    option = right ? payload.fetch("correct_option_id") : (round.arena_question_snapshot.option_ids - [payload.fetch("correct_option_id")]).first
    at { Arena::RecordAnswer.call(actor: actor, round: round, option_id: option, idempotency_key: SecureRandom.uuid) }
  end

  test "explain closes a presented question atomically and holds its answer until the host continues" do
    round = open_question
    answer(round)
    command("pause")
    assert_equal "paused", round.reload.state
    command("explain")
    assert_equal "paused", @room.reload.state
    assert_equal "results", round.reload.state
    assert_nil round.advance_at
    state = at { Arena::SessionView.call(actor: @student, session: @room) }
    assert state.dig(:round,:result,:correct)
    @now += 1.hour
    at { Arena::Game.settle!(actor: @student, session: @room) }
    assert_equal "results", round.reload.state
    assert_raises(Arena::Forbidden) { command("next", actor: @student) }
    command("next")
    assert_equal "live", @room.reload.state
    assert_equal "ready", @room.arena_rounds.find_by!(position: 2).state
    assert_equal 1, ArenaAnswer.where(arena_round: round).count
  end

  test "finish preserves the presented question and accepted points while unplayed questions are neutral" do
    round = open_question
    answer(round)
    command("pause")
    command("finish")
    assert_equal "completed", @room.reload.state
    assert_equal "results", round.reload.state
    assert_equal 2, @room.arena_rounds.where(state: "void").count
    row = Arena::Scoreboard.rows(@room).find { |entry| entry[:membership_id] == @member.id }
    assert_equal 1, row[:correct]
    assert_equal 1, row[:total]
    assert_operator row[:points], :>, 0
    report = Arena::Report.call(actor: @host, session: @room)
    student = report[:players].find { |entry| entry[:nickname] == "Sabiá" }
    assert_equal [1,0,0,1], student.values_at(:correct,:incorrect,:unanswered,:total)
    assert_equal row[:points], student[:points]
    assert_equal 2, report[:void_count]
  end

  test "leave is private idempotent and preserves a departing winner without reopening play" do
    round = open_question
    answer(round)
    before = ArenaEvent.count
    at { Arena::Lobby.leave!(actor: @student, session: @room) }
    at { Arena::Lobby.leave!(actor: @student, session: @room) }
    assert_equal before + 1, ArenaEvent.count
    assert_equal "left", @member.reload.status
    assert_raises(Arena::Forbidden) { Arena::Lobby.leave!(actor: @other, session: @room) }
    assert_raises(Arena::InvalidTransition) { Arena::Lobby.leave!(actor: @host, session: @room) }
    assert_raises(Arena::Forbidden) { answer(round) }
    state = at { Arena::SessionView.call(actor: @student, session: @room) }
    assert state[:departed]
    refute state[:participant]
    assert_nil state[:round]
    assert_raises(Arena::Unavailable) { Arena::Join.call(actor: @student, code: Arena::Invites.code(@room), nickname: "Voltei") }
    command("finish")
    final = at { Arena::SessionView.call(actor: @student, session: @room) }
    assert_equal "podium", final[:phase]
    assert final[:podium].any? { |row| row[:you] && row[:nickname] == "Sabiá" }
    assert_equal 1, final.dig(:own_result,:correct)
  end

  test "report is owner only terminal and distinguishes wrong missing void and legacy time" do
    assert_raises(Arena::InvalidTransition) { Arena::Report.call(actor: @host, session: @room) }
    round = open_question
    answer(round, right: false)
    command("finish")
    assert_raises(Arena::Forbidden) { Arena::Report.call(actor: @student, session: @room) }
    assert_raises(Arena::Forbidden) { Arena::Report.call(actor: @other, session: @room) }
    report = Arena::Report.call(actor: @host, session: @room)
    student = report[:players].find { |row| row[:nickname] == "Sabiá" }
    assert_equal [0,1,0], student.values_at(:correct,:incorrect,:unanswered)
    host = report[:players].find { |row| row[:nickname] == "Maestro" }
    assert_equal [0,0,1], host.values_at(:correct,:incorrect,:unanswered)
    assert_equal "incorrect", student[:questions].sole[:outcome]
    assert_equal 1, report[:questions].size
    refute_match(/user_id|membership_id|@example.test|isolated-arena-password/, report.to_json)
    assert_equal 2, report[:void_count]
  end

  test "a departed lobby member never sees new arrivals or private game projections" do
    Arena::Lobby.leave!(actor: @student, session: @room)
    Arena::Join.call(actor: @other, code: Arena::Invites.code(@room), nickname: "Chegou depois")
    state = Arena::SessionView.call(actor: @student, session: @room)
    assert state[:departed]
    refute state.key?(:roster)
    refute state.key?(:round)
    refute state.key?(:ranking)
    refute_includes state.to_json, "Chegou depois"
  end
end
