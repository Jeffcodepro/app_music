require "test_helper"
require_relative "../../support/arena_foundation_helpers"

class ArenaPilotTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers

  setup do
    @host, @student = arena_user, arena_user
    arena_grant(@host)
    @content = Arena::Catalog.create_preview!
  end

  def create_game
    Arena::Game.create!(actor: @host, content_version: @content, title: "Leitura em grupo", question_count: 2, duration_seconds: 30, technical_preview: true)
  end

  test "reference package verifies every note and rejects musical corruption" do
    assert_equal %w[E4 F4 G4 A4 B4 C5 D5 E5 F5], @content.body.fetch("exercises").map { |e| e.fetch("pitch_name") }
    @content.body.fetch("exercises").each_with_index do |exercise, index|
      assert_equal index, exercise.fetch("staff_position_index")
      assert Arena::ReadingContent.validate!(exercise)
      corrupt = exercise.deep_dup.merge("pitch_name" => "C1")
      assert_raises(Arena::InvalidContent) { Arena::ReadingContent.validate!(corrupt) }
    end
  end

  test "technical content requires local opt in and cannot masquerade as reviewed publication" do
    assert_raises(Arena::InvalidContent) do
      Arena::Game.create!(actor: @host, content_version: @content, title: "No approval", question_count: 2, duration_seconds: 30)
    end
    assert_nil @content.reviewer_reference
    refute @content.published?
    session = create_game
    assert_equal "lobby_open", session.state
    assert_equal 2, session.arena_rounds.count
    assert session.invite_digest
    assert_not_equal Arena::Invites.code(session), session.invite_ciphertext
  end

  test "join is idempotent and invitation never grants host authority" do
    session = create_game
    code = Arena::Invites.code(session)
    first = Arena::Join.call(actor: @student, code: code, nickname: "Sabiá")
    assert_equal first.id, Arena::Join.call(actor: @student, code: code, nickname: "Outro").id
    assert_equal 1, session.arena_memberships.count
    assert_raises(Arena::Forbidden) { Arena::Game.command!(actor: @student, session: session, command: "start", expected_version: session.reload.lock_version) }
    assert_raises(Arena::Unavailable) { Arena::Join.call(actor: arena_user, code: "INVALID", nickname: "Aluno") }
    assert_raises(Arena::Unavailable) { Arena::Join.call(actor: arena_user, code: code, nickname: "<script>alert(1)</script>") }
  end

  test "full game reveals results only after close and never awards individual XP" do
    session = create_game
    member = Arena::Join.call(actor: @student, code: Arena::Invites.code(session), nickname: "Sabiá")
    before = [StudyActivity.count, StudyActivity.sum(:xp_earned), ExerciseAttempt.count]
    command = ->(name) { Arena::Game.command!(actor: @host, session: session, command: name, expected_version: session.reload.lock_version) }
    command.call("start")
    round = session.arena_rounds.find_by!(state: "answering")
    public_state = Arena::SessionView.call(actor: @student, session: session)
    refute_match(/correct_option_id|pitch_name|pitch_label|signature|reviewer_reference/, public_state.to_json)
    assert public_state.fetch(:round).fetch(:question).fetch(:svg).start_with?("<svg")
    option = round.arena_question_snapshot.payload.fetch("correct_option_id")
    Arena::RecordAnswer.call(actor: @student, round: round, option_id: option, idempotency_key: SecureRandom.uuid)
    command.call("pause")
    assert_equal "paused", round.reload.state
    assert_raises(Arena::InvalidAnswer) { Arena::RecordAnswer.call(actor: @student, round: round, option_id: option, idempotency_key: SecureRandom.uuid) }
    command.call("resume")
    assert_equal "answering", round.reload.state
    command.call("close")
    result = Arena::SessionView.call(actor: @student, session: session)
    assert_equal 1000, result.fetch(:own_result).fetch(:points)
    refute result.key?(:ranking)
    assert_equal 1000, Arena::SessionView.call(actor: @host, session: session).fetch(:ranking).first.fetch(:points)
    command.call("next")
    command.call("close")
    command.call("next")
    assert_equal "completed", session.reload.state
    assert_equal 1000, Arena::Scoreboard.rows(session).find { |row| row[:membership_id] == member.id }.fetch(:points)
    assert_equal before, [StudyActivity.count, StudyActivity.sum(:xp_earned), ExerciseAttempt.count]
  end

  test "expired invitation rejects new entrants but an active member can recover the room" do
    room = create_game
    code = Arena::Invites.code(room)
    member = Arena::Join.call(actor: @student, code: code, nickname: "Sabiá")
    ArenaSession.where(id: room.id).update_all(created_at: 3.hours.ago, invite_expires_at: 1.hour.ago)
    assert_equal member.id, Arena::Join.call(actor: @student, code: code, nickname: "Sabiá").id
    assert_raises(Arena::Unavailable) { Arena::Join.call(actor: arena_user, code: code, nickname: "Outro") }
  end
end
