require "test_helper"
require_relative "../../support/arena_foundation_helpers"

class ArenaPlayableFlowTest < ActionDispatch::IntegrationTest
  include ArenaFoundationHelpers

  setup do
    @host, @student, @stranger = arena_user, arena_user, arena_user
    arena_grant(@host)
    @content = Arena::Catalog.create_preview!
    Arena::Catalog.publish!(content: @content, reviewer_reference: SecureRandom.uuid)
    @teacher = open_session
    @learner = open_session
    sign_in(@teacher, @host)
    sign_in(@learner, @student)
  end

  def sign_in(client, user)
    client.post user_session_path, params: { user: { email: user.email, password: "isolated-arena-password" } }
  end

  def create_room
    @teacher.post app_arena_sessions_path, params: { host_avatar: "owl", host_nickname: "Maestro", title: "Turma de leitura", content_version_id: @content.id, question_count: 2, duration_seconds: 30, experience: "facilitated" }
    assert_response_from(@teacher, 303)
    ArenaSession.where(host: @host).order(:created_at).last
  end

  def assert_response_from(client, status)
    assert_equal status, client.response.status, client.response.body[0, 300]
  end

  test "any authenticated account can create without a grant or subscription and cannot forge the owner" do
    @learner.get app_arena_path
    assert_response_from(@learner, 200)
    assert_select_from = Nokogiri::HTML(@learner.response.body)
    assert assert_select_from.at_css("form[action='#{prepare_app_arena_path}']")
    assert assert_select_from.at_css("form[action='#{app_arena_sessions_path}']")
    assert_nil @student.plan
    refute ArenaHostGrant.active.exists?(user: @student)
    @learner.post app_arena_sessions_path, params: { host_avatar: "owl", host_nickname: "Maestro", content_version_id: @content.id, title: "Minha sala", question_count: 1, duration_seconds: 30, host_id: @host.id }
    assert_response_from(@learner, 303)
    own_room = ArenaSession.find_by!(host: @student)
    @learner.post command_app_arena_session_path(own_room), params: { command: "end", version: own_room.lock_version }
    assert_response_from(@learner, 303)
    assert_equal "cancelled", own_room.reload.state
    assert_equal 0, ArenaSession.where(host: @host).count
    @teacher.get app_arena_path
    assert_response_from(@teacher, 200)
    assert_includes @teacher.response.body, "Criar sala e abrir lobby"
  end

  test "anonymous users cannot create rooms" do
    anonymous = open_session
    assert_no_difference "ArenaSession.count" do
      anonymous.post app_arena_sessions_path, params: { host_avatar: "owl", host_nickname: "Maestro", content_version_id: @content.id, title: "Anonymous", question_count: 1, duration_seconds: 30 }
    end
    assert_response_from(anonymous, 302)
    assert_equal user_session_path, URI(anonymous.response.location).path
  end

  test "opening or submitting your own invitation returns to your room without creating a participant" do
    room = create_room
    code = Arena::Invites.code(room)
    @teacher.get app_arena_path(code: code)
    assert_response_from(@teacher, 303)
    assert_equal app_arena_session_path(room), URI(@teacher.response.location).path
    @teacher.post join_app_arena_path, params: { avatar_id: "cat", code: code, nickname: "Anfitrião" }
    assert_response_from(@teacher, 303)
    assert_equal app_arena_session_path(room), URI(@teacher.response.location).path
    assert_equal 0, room.arena_memberships.count
  end

  test "login keeps the invitation and a pasted full link can be used as the code" do
    room = create_room
    code = Arena::Invites.code(room)
    link = app_arena_url(code: code)
    fresh = open_session
    fresh.get link
    assert_response_from(fresh, 302)
    sign_in(fresh, @stranger)
    assert_response_from(fresh, 303)
    assert_equal app_arena_path(code: code), URI(fresh.response.location).request_uri
    fresh.follow_redirect!
    assert_response_from(fresh, 303)
    fresh.follow_redirect!
    assert_response_from(fresh, 200)
    assert_includes fresh.response.body, "Lobby da sala"
    fresh.post join_app_arena_path, params: { avatar_id: "cat", code: link, nickname: "Convidado" }
    assert_response_from(fresh, 303)
    assert_equal @stranger.id, room.arena_memberships.sole.user_id
  end

  test "expired invitation is shown honestly and only its owner can renew it" do
    room = create_room
    original_code = Arena::Invites.code(room)
    # Represent an old lobby without weakening its readonly creation identity.
    ArenaSession.where(id: room.id).update_all(created_at: 3.hours.ago, invite_expires_at: 1.minute.ago)
    room.reload
    @teacher.get app_arena_session_path(room)
    assert_includes @teacher.response.body, "Convite expirado"
    assert_nil Nokogiri::HTML(@teacher.response.body).at_css('svg[data-arena-invite-qr]')
    @learner.post command_app_arena_session_path(room), params: { command: "renew_invite", version: room.lock_version }
    assert_response_from(@learner, 404)
    @teacher.post command_app_arena_session_path(room), params: { command: "renew_invite", version: room.reload.lock_version }
    assert_response_from(@teacher, 303)
    renewed_code = Arena::Invites.code(room.reload)
    refute_equal original_code, renewed_code
    @learner.post join_app_arena_path, params: { avatar_id: "cat", code: original_code, nickname: "Aluno" }
    assert_response_from(@learner, 422)
    @learner.post join_app_arena_path, params: { avatar_id: "cat", code: renewed_code, nickname: "Aluno" }
    assert_response_from(@learner, 303)
  end

  test "two real HTTP sessions complete a game without leaking answers or personal account data" do
    room = create_room
    @learner.post join_app_arena_path, params: { avatar_id: "cat", code: Arena::Invites.code(room), nickname: "Sabiá", user_id: @stranger.id }
    assert_response_from(@learner, 303)
    assert_equal @student.id, room.arena_memberships.sole.user_id
    @teacher.post command_app_arena_session_path(room), params: { command: "start", version: room.reload.lock_version }
    assert_response_from(@teacher, 303)
    @learner.get app_arena_session_path(room, format: :json)
    assert_response_from(@learner, 200)
    payload = @learner.response.parsed_body
    assert payload.dig("round", "question", "svg")
    refute_match(/correct_option_id|pitch_name|pitch_label|signature|invite|reviewer_reference/, @learner.response.body)
    [@host, @student, @stranger].each { |user| refute_includes @learner.response.body, user.email }
    round = room.arena_rounds.find_by!(state: "answering")
    option = round.arena_question_snapshot.payload.fetch("correct_option_id")
    @learner.post answer_app_arena_round_path(round), params: { option_id: option, idempotency_key: SecureRandom.uuid, correct: false, points: 99_999, xp: 99_999 }
    assert_response_from(@learner, 303)
    @learner.get app_arena_session_path(room, format: :json)
    assert @learner.response.parsed_body.dig("round", "answered")
    refute_includes @learner.response.body, "correct_option_id"
    @teacher.post command_app_arena_session_path(room), params: { command: "close", version: room.reload.lock_version }
    assert_response_from(@teacher, 303)
    @learner.get app_arena_session_path(room, format: :json)
    assert_includes (600..1000), @learner.response.parsed_body.dig("own_result", "points")
    refute @learner.response.parsed_body.key?("ranking")
    @teacher.get app_arena_session_path(room, format: :json)
    assert_equal "Sabiá", @teacher.response.parsed_body.fetch("ranking").first.fetch("nickname")
    assert_equal 0, @student.study_activities.sum(:xp_earned)
  end

  test "foreign rooms command forgery and stale versions are rejected" do
    room = create_room
    @learner.get app_arena_session_path(room, format: :json)
    assert_response_from(@learner, 404)
    @learner.post command_app_arena_session_path(room), params: { command: "end", version: room.lock_version }
    assert_response_from(@learner, 404)
    @teacher.post command_app_arena_session_path(room), params: { command: "to", to: "completed", version: room.lock_version }
    assert_response_from(@teacher, 422)
    @teacher.post command_app_arena_session_path(room), params: { command: "end", version: -1 }
    assert_response_from(@teacher, 409)
    assert_equal "lobby_open", room.reload.state
  end

  test "invalid join attempts consume persisted budget and never enumerate rooms" do
    10.times do
      @learner.post join_app_arena_path, params: { avatar_id: "cat", code: "invalid", nickname: "Aluno" }, as: :json
      assert_response_from(@learner, 422)
      assert_equal "Convite indisponível ou apelido inválido.", @learner.response.parsed_body.fetch("error")
    end
    @learner.post join_app_arena_path, params: { avatar_id: "cat", code: "invalid", nickname: "Aluno" }, as: :json
    assert_response_from(@learner, 429)
    assert_equal 0, ArenaMembership.where(user: @student).count
  end

  test "CSRF is required when the actual protection is enabled" do
    ActionController::Base.allow_forgery_protection = true
    @learner.post join_app_arena_path, params: { avatar_id: "cat", code: "invalid", nickname: "Aluno" }, as: :json
    assert_response_from(@learner, 422)
    assert_equal 0, ArenaMembership.where(user: @student).count
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "private Arena pages disable Turbo snapshot caching in the head only" do
    room = create_room
    @teacher.get app_arena_session_path(room)
    document = Nokogiri::HTML(@teacher.response.body)
    assert document.at_css('head meta[name="turbo-cache-control"][content="no-cache"]')
    assert_nil document.at_css('body meta[name="turbo-cache-control"]')
    assert_includes @teacher.response.headers.fetch("Cache-Control"), "no-store"
    @host.update!(plan: "Primeira Nota")
    @teacher.get app_dashboard_path
    assert_nil Nokogiri::HTML(@teacher.response.body).at_css('meta[name="turbo-cache-control"]')
  end
end
