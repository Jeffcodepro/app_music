require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"

class ArenaRoomLifecycleTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers

  setup do
    @host, @student = arena_user, arena_user
    @content = Arena::Catalog.create_preview!
  end

  def room(content: @content, **options)
    Arena::Game.create!(actor: @host, content_version: content, title: "Turma", question_count: 2, duration_seconds: 30,
      technical_preview: true, experience: "party", **options)
  end

  def command(room, name)
    Arena::Game.command!(actor: @host, session: room, command: name, expected_version: room.reload.lock_version)
  end

  test "lobbies and old unconfigured preparations never prevent creating another lobby" do
    3.times { arena_session(@host) }
    games = 4.times.map { room }
    assert_equal ["lobby_open"], games.map(&:state).uniq
    assert_equal 8, games.sum { |game| game.arena_rounds.count }
    assert games.all? { |game| Arena::Invites.code(game).present? }
  end

  test "only two games can start and ending one releases a slot without changing the other" do
    one, two, three = 3.times.map { room }
    command(one,"start")
    command(two,"start")
    command(one,"pause")
    old_version = three.lock_version
    error = assert_raises(Arena::Unavailable) { command(three,"start") }
    assert_match(/duas|2 partidas/, error.message)
    assert_equal "lobby_open", three.reload.state
    assert_equal old_version, three.lock_version
    assert_equal ["queued"], three.arena_rounds.pluck(:state).uniq
    assert_raises(Arena::Unavailable) do
      Arena::Sessions.transition!(actor: @host, session: three, to: "lobby_locked", expected_version: three.lock_version)
    end
    command(one,"finish")
    command(three,"start")
    assert_equal "live", three.reload.state
    assert_equal "live", two.reload.state
    assert_equal 2, ArenaSession.where(host: @host, state: ArenaSession::IN_PROGRESS).count
  end

  test "audio preparation reserves a slot and cancelling it releases that slot" do
    audio = Arena::MusicContent.create_preview!(area: "percepcao", level: "1", kind: "interval")
    one, two = 2.times.map { room(content: audio, listening_repetitions: 2) }
    three = room
    [one,two].each { |game| command(game,"start"); assert Arena::AudioCheck.pending?(game.reload) }
    assert_raises(Arena::Unavailable) { command(three,"start") }
    command(one,"finish")
    command(three,"start")
    assert_equal "cancelled", one.reload.state
    assert_equal "live", three.reload.state
  end

  test "preparations without content can be closed only by their owner without deleting history" do
    old = arena_session(@host)
    events = old.arena_events.count
    assert_raises(Arena::Forbidden) do
      Arena::Game.command!(actor: @student, session: old, command: "finish", expected_version: old.lock_version)
    end
    command(old,"finish")
    assert_equal "cancelled", old.reload.state
    assert_equal events + 1, old.arena_events.count
    assert ArenaSession.exists?(old.id)
    assert_raises(Arena::InvalidTransition) { command(old,"finish") }
    assert_equal events + 1, old.arena_events.count
  end

  test "ending an interrupted game preserves answers snapshots results and score" do
    game = room
    command(game,"start")
    round = game.arena_rounds.find_by!(state: "ready")
    Arena::DatabaseClock.stub(:now, round.answer_open_at) { Arena::Game.settle!(actor: @host, session: game) }
    Arena::DatabaseClock.stub(:now, round.reload.answer_open_at + 0.01) do
      Arena::RecordAnswer.call(actor: @host, round: round, option_id: round.arena_question_snapshot.payload.fetch("correct_option_id"), idempotency_key: SecureRandom.uuid)
    end
    command(game,"close")
    game.update!(state: "interrupted")
    points = Arena::Scoreboard.rows(game)
    answers, snapshots = game.arena_answers.pluck(:id), game.arena_question_snapshots.pluck(:id)
    command(game,"finish")
    assert_equal "cancelled", game.reload.state
    assert_equal "results", round.reload.state
    assert_equal points, Arena::Scoreboard.rows(game)
    assert_equal answers, game.arena_answers.pluck(:id)
    assert_equal snapshots, game.arena_question_snapshots.pluck(:id)
    assert_equal ["void"], game.arena_rounds.where.not(id: round.id).pluck(:state)
  end
end
