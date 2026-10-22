require "test_helper"
require "minitest/mock"
require_relative "../../support/arena_foundation_helpers"
class ArenaEncoreFlowTest < ActionDispatch::IntegrationTest
  include ArenaFoundationHelpers

  test "two local preview room requests reuse the musical content and open both lobbies" do
    host = arena_user
    post user_session_path, params: { user: { email: host.email, password: "isolated-arena-password" } }
    config = { prepare_lobby: "1", title: "Banda de amigos", visibility: "private", capacity: "10",
      host_mode: "play", music_area: "percepcao", music_level: "1", music_kind: "mixed",
      question_count: "5", duration_seconds: "30" }
    rooms = []
    Arena::Catalog.stub(:technical_preview?, true) do
      assert_difference "ArenaContentVersion.count", 1 do
        assert_difference "ArenaSession.count", 2 do
          2.times do
            post app_arena_sessions_path, params: config
            assert_response :see_other
            follow_redirect!
            assert_response :success
            assert_select "h1", "Banda de amigos"
            rooms << ArenaSession.where(host: host).order(:created_at).last
          end
        end
      end
    end
    assert_not_equal rooms.first.id, rooms.last.id
    assert_equal rooms.first.arena_content_version_id, rooms.last.arena_content_version_id
    assert rooms.all? { |room| room.experience == "party" && room.presentation_mode == "individual" && room.arena_rounds.count == 5 }
  end

  test "reported perception configuration creates a five-question party on the migrated schema" do
    host = arena_user
    content = Arena::MusicContent.create_preview!(area: "percepcao", level: "1", kind: "mixed")
    Arena::Catalog.publish!(content: content, reviewer_reference: SecureRandom.uuid)
    post user_session_path, params: { user: { email: host.email, password: "isolated-arena-password" } }
    activity_count = StudyActivity.count

    assert_difference "ArenaSession.count", 1 do
      assert_difference "ArenaRound.count", 5 do
        post app_arena_sessions_path, params: {
          prepare_lobby: "1", title: "Banda de amigos", visibility: "private", capacity: "10",
          host_mode: "play", music_area: "percepcao", music_level: "1", music_kind: "mixed",
          question_count: "5", duration_seconds: "30"
        }
      end
    end
    assert_response :see_other
    room = ArenaSession.find_by!(host: host)
    assert_equal "party", room.experience
    assert_equal "individual", room.presentation_mode
    assert_equal 10, room.capacity
    assert_equal 30, room.duration_seconds
    assert_empty room.arena_memberships
    assert_equal 5, room.arena_question_snapshots.count
    assert room.arena_question_snapshots.all? { |snapshot| snapshot.payload_version == Arena::MusicContent::TYPE && snapshot.payload.dig("entry", "area") == "percepcao" && snapshot.payload.dig("entry", "level") == 1 }
    assert_equal activity_count, StudyActivity.count

    follow_redirect!
    assert_response :success
    assert_select "h1", "Banda de amigos"
    assert_select "form[action='#{ready_app_arena_session_path(room)}']", count: 1
  end

  test "a registered presenter opens an audio room without a player and the learner answers only after shared listening" do
    host, student, outsider = arena_user, arena_user, arena_user
    content = Arena::MusicContent.create_preview!(area: "percepcao", level: "1", kind: "interval")
    Arena::Catalog.publish!(content: content, reviewer_reference: SecureRandom.uuid)
    presenter, learner, foreign = open_session, open_session, open_session
    [[presenter,host],[learner,student],[foreign,outsider]].each { |client,user| client.post user_session_path, params: { user: { email: user.email, password: "isolated-arena-password" } } }
    presenter.post app_arena_sessions_path, params: { prepare_lobby: "1", host_mode: "present", music_area: "percepcao", music_level: "1", music_kind: "interval", title: "Turma", question_count: 15, duration_seconds: 10, capacity: 40 }
    assert_equal 303, presenter.response.status
    room = ArenaSession.find_by!(host: host)
    assert_equal "presenter", room.presentation_mode
    assert_empty room.arena_memberships
    presenter.follow_redirect!
    assert_equal 200, presenter.response.status
    assert_includes presenter.response.body, "arena-invite-code"
    Arena::Join.call(actor: student, code: Arena::Invites.code(room), nickname: "Sabiá", avatar_id: "dragon")
    now = Time.current
    Arena::DatabaseClock.stub(:now,now) { presenter.post command_app_arena_session_path(room), params: { command: "start", version: room.reload.lock_version } }
    presenter.follow_redirect!
    assert_equal 200, presenter.response.status
    assert_includes presenter.response.body, "Passagem de som"
    Arena::DatabaseClock.stub(:now,now) { presenter.post audio_ready_app_arena_session_path(room), params: { check_id: room.reload.audio_check_id, ready: true }, as: :json }
    assert_equal 204, presenter.response.status
    presenter.get app_arena_session_path(room)
    assert_equal 1, Nokogiri::HTML(presenter.response.body).css('template[data-arena-audio-template] [data-controller="arena-audio interval-player"]').size
    round = room.arena_rounds.find_by!(position: 1)
    learner.get app_arena_session_path(room, format: :json)
    state = learner.response.parsed_body
    assert_equal "listening", state["phase"]
    assert_nil state.dig("round","deadline_at")
    assert_nil state.dig("round","playback","token")
    refute_match(/source_option|correct_option|reference_pitch|signature/, state.to_json)
    foreign.post playback_app_arena_round_path(round), params: { generation: 1 }, as: :json
    assert_equal 404, foreign.response.status
    learner.post playback_app_arena_round_path(round), params: { generation: 1 }, as: :json
    assert_equal 404, learner.response.status
    assert_equal "sequence-v1", room.listening_policy
    1.upto(3) do |index|
      now = Arena::Playback.cue_at(round.reload, index) + 2.1
      Arena::DatabaseClock.stub(:now,now) { presenter.post playback_app_arena_round_path(round), params: { generation: 1, listen: index, points: 999 }, as: :json }
      assert_equal 200, presenter.response.status
      receipt = presenter.response.parsed_body
      now += receipt.fetch("minimum_seconds") + 0.2
      Arena::DatabaseClock.stub(:now,now) { presenter.post complete_playback_app_arena_round_path(round), params: { generation: 1, listen: index, token: receipt.fetch("token") }, as: :json }
      assert_equal 204, presenter.response.status
    end
    now = Arena::Playback.ends_at(room, round.reload)
    Arena::DatabaseClock.stub(:now,now) { learner.post settle_app_arena_session_path(room) }
    now += 3
    Arena::DatabaseClock.stub(:now,now) { learner.post settle_app_arena_session_path(room) }
    assert_equal "answering", round.reload.state
    Arena::DatabaseClock.stub(:now,now) { learner.post answer_app_arena_round_path(round), params: { option_id: round.arena_question_snapshot.option_ids.first, idempotency_key: SecureRandom.uuid }, as: :json }
    assert_equal 200, learner.response.status
    assert_equal 1, room.arena_answers.count
    assert_empty room.arena_memberships.where(user: host)
    Arena::DatabaseClock.stub(:now,now) { presenter.post command_app_arena_session_path(room), params: { command: "finish", version: room.reload.lock_version } }
    report = Arena::Report.call(actor: host, session: room)
    assert_equal "Percepção · Intervalos", report[:questions].sole[:topic]
    assert_equal "Nível 1", report[:questions].sole[:level]
    assert_equal 14, report[:void_count]
    learner.get app_arena_session_path(room, format: :json)
    assert learner.response.parsed_body["podium"].any?
    assert learner.response.parsed_body["share"]
    refute presenter.response.parsed_body.is_a?(Hash) && presenter.response.parsed_body.key?("share")
  end
  test "direct HTTP creation also enforces the selected listening budget" do
    host = arena_user
    content = Arena::MusicContent.create_preview!(area: "percepcao", level: "1", kind: "interval")
    Arena::Catalog.publish!(content: content, reviewer_reference: SecureRandom.uuid)
    post user_session_path, params: { user: { email: host.email, password: "isolated-arena-password" } }
    config = { music_area: "percepcao", music_level: "1", music_kind: "interval", title: "Escuta direta", question_count: 1, duration_seconds: 10,
      experience: "party", host_nickname: "Maestro", host_avatar: "robot", listening_repetitions: 2 }
    post app_arena_sessions_path, params: config
    assert_response :see_other
    room = ArenaSession.find_by!(host: host)
    assert_equal "sequence-v1", room.listening_policy
    assert_equal 2, room.listening_repetitions
    assert_no_difference "ArenaSession.count" do
      post app_arena_sessions_path, params: config.merge(listening_repetitions: 6)
      assert_response :unprocessable_entity
    end
  end

end
