require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"

class ArenaSocialTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers

  setup do
    @host, @student = arena_user, arena_user
    @content = Arena::Catalog.create_preview!
    @now = Time.current
  end

  def at(time = @now, &block) = Arena::DatabaseClock.stub(:now, time, &block)

  def room(**options)
    at { Arena::Game.create!(actor: @host, content_version: @content, title: "Banda de amigos", question_count: 3,
      duration_seconds: 10, technical_preview: true, experience: "party", host_nickname: "Maestro",
      host_avatar: "fox", scoring_version: "speed-streak-v1", visibility: "public", capacity: 3, **options) }
  end

  def command(game, name)
    at { Arena::Game.command!(actor: @host, session: game, command: name, expected_version: game.reload.lock_version) }
  end

  def open_round(game)
    command(game, "start") if game.reload.state == "lobby_open"
    round = game.arena_rounds.find_by!(state: "ready")
    @now = round.answer_open_at
    at { Arena::Game.settle!(actor: @host, session: game) }
    round.reload
  end

  def answer(round, user: @host, elapsed: 0, correct: true, key: SecureRandom.uuid)
    option = correct ? round.arena_question_snapshot.payload.fetch("correct_option_id") : (round.arena_question_snapshot.option_ids - [round.arena_question_snapshot.payload.fetch("correct_option_id")]).first
    at(@now + elapsed / 1000.0) { Arena::RecordAnswer.call(actor: user, round: round, option_id: option, idempotency_key: key) }
  end

  test "literal speed examples and bounded streak bonus use integer server time" do
    [[0,1000],[2500,900],[5000,800],[9999,600]].each do |elapsed,points|
      assert_equal points, Arena::Scoring.points(duration_ms: 10000, elapsed_ms: elapsed, streak: 1)
    end
    assert_equal [1000,1100,1200,1300,1400,1400], (1..6).map { |streak| Arena::Scoring.points(duration_ms: 10000, elapsed_ms: 0, streak: streak) }
    [nil,-1,10000,Float::NAN].each { |value| assert_raises(Arena::InvalidContent) { Arena::Scoring.points(duration_ms: 10000, elapsed_ms: value, streak: 1) } }
  end

  test "confirmed avatar is stored and only public lobbies with vacancies are discoverable" do
    game = room(capacity: 2)
    assert_equal "fox", game.arena_memberships.sole.avatar_id
    assert_includes Arena::Directory.rows.map { |row| row[:id] }, game.id
    refute_match(/invite|nickname|user_id|correct_option|ciphertext/, Arena::Directory.rows.to_json)
    member = Arena::Join.call(actor: @student, public_session_id: game.id, nickname: "Sabiá", avatar_id: "owl")
    assert_equal "owl", member.avatar_id
    refute_includes Arena::Directory.rows.map { |row| row[:id] }, game.id
    assert_equal member, Arena::Join.call(actor: @student, public_session_id: game.id, nickname: "Outro", avatar_id: "cat")
    private_game = room(visibility: "private")
    assert_raises(Arena::Unavailable) { Arena::Join.call(actor: @student, public_session_id: private_game.id, nickname: "Sabiá", avatar_id: "owl") }
    assert_raises(Arena::Unavailable) { Arena::Join.call(actor: arena_user, code: Arena::Invites.code(private_game), nickname: "Sabiá", avatar_id: "https://invalid.test/avatar.svg") }
    refute_includes Arena::Directory.rows.map { |row| row[:id] }, private_game.id
  end

  test "only owner may remove another member before start and removal prevents reentry" do
    game = room
    member = Arena::Join.call(actor: @student, public_session_id: game.id, nickname: "Sabiá", avatar_id: "cat")
    state = Arena::SessionView.call(actor: @host, session: game)
    assert state.fetch(:roster).find { |row| row[:id] == member.id }[:removable]
    assert_raises(Arena::Forbidden) { Arena::Lobby.remove!(actor: @student, session: game, membership_id: member.id, expected_version: game.reload.lock_version) }
    assert_raises(Arena::InvalidTransition) { Arena::Lobby.remove!(actor: @host, session: game, membership_id: game.arena_memberships.find_by!(user: @host).id, expected_version: game.reload.lock_version) }
    Arena::Lobby.remove!(actor: @host, session: game, membership_id: member.id, expected_version: game.reload.lock_version)
    assert_equal "removed", member.reload.status
    assert_raises(Arena::Unavailable) { Arena::Join.call(actor: @student, public_session_id: game.id, nickname: "Voltei", avatar_id: "cat") }
    assert_raises(Arena::Forbidden) { Arena::SessionView.call(actor: @student, session: game) }
    command(game, "start")
    assert_raises(Arena::InvalidTransition) { Arena::Lobby.remove!(actor: @host, session: game, membership_id: member.id, expected_version: game.reload.lock_version) }
  end

  test "speed and streak feedback matches total and replay cannot change elapsed time" do
    game = room
    key = SecureRandom.uuid
    expected = [900,1000,0]
    3.times do |i|
      round = open_round(game)
      ack = answer(round, elapsed: 2500, correct: i < 2, key: i.zero? ? key : SecureRandom.uuid)
      if i.zero?
        saved = ArenaAnswer.find(ack[:answer_id])
        assert_equal 2500, saved.response_elapsed_ms
        assert_equal ack, answer(round, elapsed: 5000, key: key)
        assert_equal 2500, saved.reload.response_elapsed_ms
      end
      @now = round.deadline_at
      at { Arena::Game.settle!(actor: @host, session: game) }
      state = at { Arena::SessionView.call(actor: @host, session: game) }
      assert_equal expected[i], state.dig(:round,:result,:points)
      assert_equal expected.take(i + 1).sum, state.dig(:own_result,:points)
      @now = round.reload.advance_at
      at { Arena::Game.settle!(actor: @host, session: game) }
    end
    assert_equal 0, Arena::Scoreboard.rows(game).sole[:streak]
  end

  test "pause does not reinterpret accepted answers or count paused duration" do
    game = room(question_count: 1)
    Arena::Join.call(actor: @student, public_session_id: game.id, nickname: "Sabiá", avatar_id: "owl")
    round = open_round(game)
    saved = ArenaAnswer.find(answer(round, elapsed: 2000)[:answer_id])
    @now += 3.seconds
    command(game, "pause")
    @now += 2.hours
    command(game, "resume")
    answer(round.reload, user: @student, elapsed: 1000)
    @now += 2.seconds
    at { Arena::Game.settle!(actor: @host, session: game) }
    assert_equal 2000, saved.reload.response_elapsed_ms
    rows = Arena::Scoreboard.rows(game)
    assert_equal 920, rows.find { |row| row[:membership_id] == saved.arena_membership_id }[:points]
    other = ArenaAnswer.find_by!(arena_round: round, arena_membership: game.arena_memberships.find_by!(user: @student))
    assert_in_delta 4000, other.response_elapsed_ms, 1
    assert_equal 840, rows.find { |row| row[:membership_id] == other.arena_membership_id }[:points]
  end

  test "old scoring version stays accuracy based and configuration cannot be rewritten" do
    game = room(scoring_version: "accuracy-1000-v1", question_count: 1)
    round = open_round(game)
    answer(round, elapsed: 9999)
    @now = round.deadline_at
    at { Arena::Game.settle!(actor: @host, session: game) }
    assert_equal 1000, Arena::Scoreboard.rows(game).sole[:points]
    %w[scoring_version capacity visibility duration_seconds].zip(["speed-streak-v1",20,"private",20]).each do |attribute,value|
      connection = ArenaSession.connection
      assert_raises(ActiveRecord::StatementInvalid) do
        ArenaSession.transaction(requires_new: true) { connection.execute("UPDATE arena_sessions SET #{connection.quote_column_name(attribute)}=#{connection.quote(value)} WHERE id=#{connection.quote(game.id)}") }
      end
    end
  end

  test "ten second duration bounds and avatar anonymization are enforced" do
    game = room
    [9,121,"10.5","ten"].each do |duration|
      assert_raises(Arena::InvalidContent) { room(duration_seconds: duration) }
    end
    @host.destroy!
    assert_equal "neutral", game.arena_memberships.find_by!(user_id: nil).avatar_id
    assert_equal "cancelled", game.reload.state
  end

  test "direct inserts cannot create speed answers without a configured duration" do
    game = Arena::Sessions.create!(actor: @host, title: "Sem duração", scoring_version: "speed-streak-v1")
    round = answering_round(game)
    member = arena_membership(game, @student)
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaSession.transaction(requires_new: true) do
        ArenaAnswer.create!(arena_session: game, arena_round: round, arena_membership: member, option_id: "b",
          idempotency_key: SecureRandom.uuid, accepted_at: Time.current, response_elapsed_ms: 0)
      end
    end
  end

  test "missing answer resets combo and void round does not break it" do
    game = room(question_count: 4)
    expected = [1000,0,1000]
    3.times do |i|
      round = open_round(game)
      answer(round) unless i == 1
      @now = round.deadline_at
      at { Arena::Game.settle!(actor: @host, session: game) }
      assert_equal expected[i], at { Arena::SessionView.call(actor: @host, session: game) }.dig(:round,:result,:points)
      @now = round.reload.advance_at
      at { Arena::Game.settle!(actor: @host, session: game) }
    end
    fourth = open_round(game)
    fourth.update!(state: "void")
    assert_equal 1, Arena::Scoreboard.rows(game).sole[:streak]
    assert_equal 2000, Arena::Scoreboard.rows(game).sole[:points]
  end

  test "same point bucket uses accepted time for tie break and identical time shares place" do
    game = room(question_count: 1)
    Arena::Join.call(actor: @student, public_session_id: game.id, nickname: "Sabiá", avatar_id: "owl")
    round = open_round(game)
    answer(round, elapsed: 1001)
    answer(round, user: @student, elapsed: 1002)
    @now = round.deadline_at
    at { Arena::Game.settle!(actor: @host, session: game) }
    rows = Arena::Scoreboard.rows(game)
    assert_equal [959,959], rows.map { |row| row[:points] }
    assert_equal [1,2], rows.map { |row| row[:place] }
    assert_equal game.arena_memberships.find_by!(user: @host).id, rows.first[:membership_id]
    tied = room(question_count: 1)
    Arena::Join.call(actor: @student, public_session_id: tied.id, nickname: "Sabiá", avatar_id: "owl")
    round = open_round(tied)
    answer(round, elapsed: 1000)
    answer(round, user: @student, elapsed: 1000)
    @now = round.deadline_at
    at { Arena::Game.settle!(actor: @host, session: tied) }
    assert_equal [1,1], Arena::Scoreboard.rows(tied).map { |row| row[:place] }
  end

  test "restored old anonymization trigger fails closed after social migration" do
    connection = ArenaSession.connection
    ArenaSession.transaction(requires_new: true) do
      connection.execute("DROP TRIGGER arena_account_removal ON users")
      connection.execute("CREATE TRIGGER arena_account_removal BEFORE DELETE ON users FOR EACH ROW EXECUTE FUNCTION arena_f1_anonymize_account()")
      assert_raises(Arena::SchemaIntegrity::MissingProtection) { Arena::SchemaIntegrity.verify! }
      raise ActiveRecord::Rollback
    end
    assert Arena::SchemaIntegrity.verify!
  end
end
