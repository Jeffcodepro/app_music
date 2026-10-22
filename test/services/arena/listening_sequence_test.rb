require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"

class ArenaListeningSequenceTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers

  def setup_room(repetitions: 3, experience: "party")
    @host, @student = arena_user, arena_user
    content = Arena::MusicContent.create_preview!(area: "percepcao", level: "1", kind: "interval")
    @room = Arena::Game.create!(actor: @host, content_version: content, title: "Escutas", question_count: 2, duration_seconds: 10,
      technical_preview: true, experience: experience, listening_repetitions: repetitions)
    @member = Arena::Join.call(actor: @student, code: Arena::Invites.code(@room), nickname: "Sol")
    @now = Time.current
    at(@now) do
      command("start")
      required = experience == "facilitated" ? [@host] : [@host, @student]
      required.each { |actor| Arena::AudioCheck.confirm!(actor: actor, session: @room, check_id: @room.reload.audio_check_id) }
      Arena::Game.settle!(actor: @host, session: @room)
    end
    @round = @room.arena_rounds.order(:position).first
  end

  def at(time, &block) = Arena::DatabaseClock.stub(:now, time, &block)
  def command(name) = Arena::Game.command!(actor: @host, session: @room, command: name, expected_version: @room.reload.lock_version)
  def listen(index, actor: @host)
    starts = Arena::Playback.cue_at(@round.reload, index) + Arena::Playback::ANNOUNCEMENT_SECONDS + 0.1
    receipt = at(starts) { Arena::Playback.start!(actor: actor, round: @round, generation: @round.playback_generation, listen: index) }
    at(starts + receipt[:minimum_seconds] + 0.2) do
      Arena::Playback.complete!(actor: actor, round: @round, generation: @round.playback_generation, listen: index, token: receipt[:token])
    end
    receipt
  end

  test "three announced slots enforce time tokens and limits without waiting for every player" do
    setup_room
    assert_equal "sequence-v1", @room.listening_policy
    assert_raises(Arena::InvalidTransition) { at(@now) { Arena::Playback.start!(actor: @host, round: @round, generation: 1, listen: 1) } }
    1.upto(3) { |index| listen(index) }
    assert_equal 3, Arena::Playback.completed(@room, @round.reload, @room.arena_memberships.find_by!(user: @host).id)
    ends = Arena::Playback.ends_at(@room, @round)
    at(ends) { Arena::Game.settle!(actor: @student, session: @room) }
    assert_in_delta ends + 3, @round.reload.answer_open_at, 0.01
    at(ends + 3) { Arena::Game.settle!(actor: @host, session: @room) }
    assert_equal "answering", @round.reload.state
    assert_raises(Arena::InvalidTransition) { at(ends + 3) { Arena::Playback.start!(actor: @host, round: @round, generation: 1, listen: 4) } }
    assert_raises(Arena::InvalidTransition) { at(ends + 3) { Arena::Playback.start!(actor: @host, round: @round, generation: 1, listen: 1) } }
    at(ends + 4) do
      assert_raises(Arena::InvalidAnswer) { Arena::RecordAnswer.call(actor: @student, round: @round, option_id: @round.arena_question_snapshot.option_ids.first, idempotency_key: SecureRandom.uuid) }
      Arena::RecordAnswer.call(actor: @host, round: @round, option_id: @round.arena_question_snapshot.payload.fetch("correct_option_id"), idempotency_key: SecureRandom.uuid)
      command("close")
    end
    scores = Arena::Scoreboard.rows(@room)
    assert_equal 1, scores.find { |row| row[:membership_id] == @room.arena_memberships.find_by!(user: @host).id }[:total]
    assert_equal 0, scores.find { |row| row[:membership_id] == @member.id }[:total]
    command("finish")
    report = Arena::Report.call(actor: @host, session: @room)
    student = report[:players].find { |row| row[:nickname] == "Sol" }
    assert_equal "technical", student[:questions].first[:outcome]
    assert_equal 0, student[:incorrect]
    assert_equal 0, student[:unanswered]
  end

  test "one and five listens work and skipped indices never establish readiness" do
    [1, 5].each do |count|
      setup_room(repetitions: count)
      listen(count)
      assert_equal count == 1, Arena::Playback.eligible?(@room, @round.reload, @room.arena_memberships.find_by!(user: @host))
      command("end")
    end
  end

  test "duplicate starts authorize no new playback and paused callbacks cannot complete or replay finished listens" do
    setup_room
    listen(1)
    starts = Arena::Playback.cue_at(@round.reload, 2) + 2.1
    receipt = at(starts) { Arena::Playback.start!(actor: @host, round: @round, generation: 1, listen: 2) }
    duplicate = at(starts) { Arena::Playback.start!(actor: @host, round: @round, generation: 1, listen: 2) }
    assert duplicate[:already_started]
    assert_equal receipt[:token], duplicate[:token]
    at(starts + 0.1) { command("pause") }
    at(starts + 1) { command("resume") }
    assert_equal 2, @round.reload.playback_generation
    assert_raises(Arena::InvalidTransition) { at(starts + 3) { Arena::Playback.complete!(actor: @host, round: @round, generation: 1, listen: 2, token: receipt[:token]) } }
    assert_equal 1, Arena::Playback.completed(@room, @round, @room.arena_memberships.find_by!(user: @host).id)
    assert_raises(Arena::InvalidTransition) { at(Arena::Playback.cue_at(@round, 1) + 2.1) { Arena::Playback.start!(actor: @host, round: @round, generation: 2, listen: 1) } }
  end

  test "presenter failure voids before answering and participants cannot play" do
    setup_room(experience: "facilitated")
    starts = Arena::Playback.cue_at(@round, 1) + 2.1
    assert_raises(Arena::Forbidden) { at(starts) { Arena::Playback.start!(actor: @student, round: @round, generation: 1, listen: 1) } }
    at(Arena::Playback.ends_at(@room, @round)) { Arena::Game.settle!(actor: @student, session: @room) }
    assert_equal "void", @round.reload.state
    assert_nil @round.answer_open_at
    assert_empty @room.arena_answers
  end

  test "configuration rejects invalid repetitions and database cannot change them after lobby" do
    setup_room
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaSession.transaction(requires_new: true) { ArenaSession.where(id: @room.id).update_all(listening_repetitions: 4) }
    end
    [0, 6, "3.5", nil].each do |count|
      next if count.nil? # nil is the explicit legacy service contract
      assert_raises(Arena::InvalidContent) { Arena::Game.create!(actor: arena_user, content_version: @room.arena_content_version, title: "Inválida", question_count: 1, duration_seconds: 10, technical_preview: true, listening_repetitions: count) }
    end
  end
  test "pause after completed listening preserves countdown timeline and no audio exclusion receives a podium" do
    setup_room(repetitions: 1)
    listen(1)
    ends = Arena::Playback.ends_at(@room, @round.reload)
    at(ends) { Arena::Game.settle!(actor: @host, session: @room) }
    original = @round.reload.listening_started_at
    at(ends + 0.5) { command("pause") }
    at(ends + 1) { command("resume") }
    assert_equal original, @round.reload.listening_started_at
    assert_equal "countdown", at(ends + 1) { Arena::SessionView.call(actor: @student, session: @room) }[:phase]
    at(ends + 4) { Arena::Game.settle!(actor: @host, session: @room) }
    at(ends + 5) { command("close"); command("finish") }
    view = Arena::SessionView.call(actor: @student, session: @room)
    assert_nil view[:own_result][:place]
    refute view[:podium].any? { |row| row[:you] }
    refute_match(/Minha posição/, view[:share][:text])
    assert_match(/Sem classificação/, view[:share][:text])
  end

  test "a later technical exclusion preserves the earlier combo and scoring denominator" do
    setup_room(repetitions: 1)
    listen(1)
    ends = Arena::Playback.ends_at(@room, @round.reload)
    at(ends) { Arena::Game.settle!(actor: @host, session: @room) }
    at(ends + 3) { Arena::Game.settle!(actor: @host, session: @room) }
    at(ends + 4) do
      Arena::RecordAnswer.call(actor: @host, round: @round, option_id: @round.arena_question_snapshot.payload.fetch("correct_option_id"), idempotency_key: SecureRandom.uuid)
      command("close")
    end
    before = Arena::Scoreboard.rows(@room).find { |row| row[:total] == 1 }
    at(ends + 5) { command("next") }
    second = @room.arena_rounds.order(:position).last
    deadline = Arena::Playback.ends_at(@room, second)
    at(deadline) { Arena::Game.settle!(actor: @host, session: @room) }
    at(deadline + 3) { Arena::Game.settle!(actor: @host, session: @room) }
    at(deadline + 4) { command("close"); command("finish") }
    after = Arena::Scoreboard.rows(@room).find { |row| row[:membership_id] == before[:membership_id] }
    assert_equal 1, after[:streak]
    assert_equal before.slice(:points, :total, :correct, :response_time_ms), after.slice(:points, :total, :correct, :response_time_ms)
  end

end
