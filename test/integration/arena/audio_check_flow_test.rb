require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"
class ArenaAudioCheckFlowTest < ActionDispatch::IntegrationTest
  include ArenaFoundationHelpers
  def setup
    @host, @student, @outsider = arena_user, arena_user, arena_user
    @owner, @learner, @foreign = open_session, open_session, open_session
    [[@owner,@host],[@learner,@student],[@foreign,@outsider]].each { |client,user| client.post user_session_path, params: { user: { email: user.email, password: "isolated-arena-password" } } }
    content = Arena::MusicContent.create_preview!(area: "percepcao", level: "1", kind: "interval")
    @room = Arena::Game.create!(actor: @host, content_version: content, title: "Som pronto", question_count: 1, duration_seconds: 10, experience: "party", listening_repetitions: 1, technical_preview: true)
    @member = Arena::Join.call(actor: @student, code: Arena::Invites.code(@room), nickname: "Sol")
    @now = Time.current
    Arena::DatabaseClock.stub(:now,@now) { Arena::Game.command!(actor: @host, session: @room, command: "start", expected_version: @room.reload.lock_version) }
  end
  def ack(client, time: @now, **extra)
    Arena::DatabaseClock.stub(:now,time) { client.post audio_ready_app_arena_session_path(@room), params: { check_id: @room.reload.audio_check_id, ready: true, **extra }, as: :json }
  end
  test "HTTP readiness is per actor and all ready starts without waiting forty five seconds" do
    ack(@foreign)
    assert_equal 404, @foreign.response.status
    ack(@owner, membership_id: @member.id, user_id: @student.id)
    assert_equal 204, @owner.response.status
    assert_nil @member.reload.audio_ready_at
    assert_equal "lobby_locked", @room.reload.state
    ack(@learner, time: @now + 6)
    assert_equal 204, @learner.response.status
    assert_equal "live", @room.reload.state
    assert_in_delta @now + 6, @room.arena_rounds.sole.listening_started_at, 0.00001
  end
  test "audio timeout redirects its own excluded player and never exposes the question or roster" do
    ack(@owner)
    Arena::DatabaseClock.stub(:now,@now + 45) { @owner.post settle_app_arena_session_path(@room) }
    assert_equal 204, @owner.response.status
    @learner.get app_arena_session_path(@room,format: :json)
    assert_equal 200, @learner.response.status
    payload = @learner.response.parsed_body
    assert_equal "audio_excluded", payload["phase"]
    %w[round roster ranking invite audio_check].each { |key| refute payload.key?(key) }
    @learner.get app_arena_session_path(@room)
    assert_equal 303, @learner.response.status
    @learner.follow_redirect!
    assert_equal 200, @learner.response.status
    assert_includes @learner.response.body, "não ativou o áudio em 45 segundos"
    @learner.post audio_ready_app_arena_session_path(@room), params: { check_id: @room.audio_check_id, ready: true }, as: :json
    assert_equal 404, @learner.response.status
    @foreign.get app_arena_session_path(@room,format: :json)
    assert_equal 404, @foreign.response.status
  end
end
