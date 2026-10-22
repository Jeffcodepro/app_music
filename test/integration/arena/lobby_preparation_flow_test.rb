require "test_helper"
require_relative "../../support/arena_foundation_helpers"

class ArenaLobbyPreparationFlowTest < ActionDispatch::IntegrationTest
  include ArenaFoundationHelpers

  setup do
    @host,@guest,@other = arena_user,arena_user,arena_user
    content = Arena::Catalog.create_preview!
    Arena::Catalog.publish!(content: content, reviewer_reference: SecureRandom.uuid)
    @config = { prepare_lobby: "1", title: "Lobby musical", content_version_id: content.id, question_count: 1, duration_seconds: 10, visibility: "public", capacity: 2 }
    @creator,@player,@outsider = open_session,open_session,open_session
    [[@creator,@host],[@player,@guest],[@outsider,@other]].each do |client,user|
      client.post user_session_path, params: { user: { email: user.email, password: "isolated-arena-password" } }
    end
  end

  def create_lobby
    @creator.post app_arena_sessions_path, params: @config.merge(experience: "facilitated")
    assert_equal 303, @creator.response.status
    ArenaSession.find_by!(host: @host)
  end

  def ready_host(room)
    @creator.post ready_app_arena_session_path(room), params: { nickname: "Maestro", avatar_id: "fox" }
    assert_equal 303, @creator.response.status
  end

  test "entry config opens room then creator confirms inside its lobby before sharing" do
    @creator.get app_arena_path
    doc = Nokogiri::HTML(@creator.response.body)
    assert_nil doc.at_css('input[name="host_avatar"]')
    assert_nil doc.at_css('input[name="nickname"]')
    assert_equal 6, doc.css('.arena-select select').size
    assert_equal '3', doc.at_css('select[name="listening_repetitions"] option[selected]')['value']
    assert doc.at_css('[data-arena-setup-target="listening"][hidden]')
    assert doc.at_css('select[name="listening_repetitions"][disabled][data-arena-setup-target="repetitions"]')
    assert doc.at_css('select[name="music_area"][data-arena-setup-target="area"]')
    room = create_lobby
    assert_equal "party", room.experience
    assert_empty room.arena_memberships
    @creator.follow_redirect!
    assert_equal 200, @creator.response.status
    assert_includes @creator.response.body, "Lobby da sala"
    assert Nokogiri::HTML(@creator.response.body).at_css("form[action='#{ready_app_arena_session_path(room)}']")
    refute_includes @creator.response.body, "arena-invite-code"
    refute_includes @creator.response.body, "Iniciar sessão"
    @creator.get app_arena_session_path(room, format: :json)
    refute @creator.response.parsed_body.key?("invite")
    @creator.post command_app_arena_session_path(room), params: { command: "start", version: room.reload.lock_version }
    assert_equal 422, @creator.response.status
    ready_host(room)
    @creator.follow_redirect!
    assert_includes @creator.response.body, "arena-invite-code"
    assert_includes @creator.response.body, "Maestro"
  end

  test "guest opens actual lobby with permission but only becomes ready after confirmation" do
    room = create_lobby
    ready_host(room)
    @outsider.get app_arena_session_path(room)
    assert_equal 404, @outsider.response.status
    before = [ArenaMembership.count,ArenaEvent.count]
    @player.get app_arena_path(code: Arena::Invites.code(room))
    assert_equal 303, @player.response.status
    assert_equal app_arena_session_path(room), URI(@player.response.location).path
    @player.follow_redirect!
    assert_equal 200, @player.response.status
    assert_includes @player.response.body, "Lobby da sala"
    assert_includes @player.response.body, "Estou pronto!"
    refute_includes @player.response.body, "Maestro"
    refute_includes @player.response.body, "data-controller=\"arena-live\""
    assert_equal before, [ArenaMembership.count,ArenaEvent.count]
    @player.get app_arena_session_path(room)
    assert_equal 200, @player.response.status
    @player.post ready_app_arena_session_path(room), params: { nickname: "Sabiá", avatar_id: "cat" }
    assert_equal 303, @player.response.status
    assert_equal before.map { |count| count + 1 }, [ArenaMembership.count,ArenaEvent.count]
    @creator.get app_arena_session_path(room)
    assert_includes @creator.response.body, 'data-arena-member-name="Sabiá"'
    assert Nokogiri::HTML(@creator.response.body).at_css('[data-arena-live-target="readyNotice"][role="status"]')
    @player.post ready_app_arena_session_path(room), params: { nickname: "Mudei", avatar_id: "robot" }
    assert_equal 303, @player.response.status
    assert_equal "Sabiá", room.arena_memberships.find_by!(user: @guest).nickname
  end

  test "full-room confirmation error keeps identity draft inside lobby without registration" do
    @config[:capacity] = 2
    room = create_lobby
    ready_host(room)
    [@player,@outsider].each do |client|
      client.post prepare_app_arena_path, params: { public_session_id: room.id }
      assert_equal 303, client.response.status
    end
    @player.post ready_app_arena_session_path(room), params: { nickname: "Sabiá", avatar_id: "cat" }
    @outsider.post ready_app_arena_session_path(room), params: { nickname: "Canário", avatar_id: "robot" }
    assert_equal 422, @outsider.response.status
    doc = Nokogiri::HTML(@outsider.response.body)
    assert_equal "Canário", doc.at_css('input[name="nickname"]')['value']
    assert doc.at_css('input[name="avatar_id"][value="robot"][checked]')
    assert_includes @outsider.response.body, "Lobby da sala"
    assert_equal 2, room.arena_memberships.count
  end

  test "owner can close a lobby without confirming an identity or consuming a player slot" do
    room = create_lobby
    @creator.get app_arena_session_path(room)
    assert_includes @creator.response.body, "Encerrar esta sala"
    @creator.post command_app_arena_session_path(room), params: { command: "end", version: room.reload.lock_version }
    assert_equal 303, @creator.response.status
    assert_equal "cancelled", room.reload.state
    assert_empty room.arena_memberships
  end
end
