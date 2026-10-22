require "test_helper"
require_relative "../../support/arena_foundation_helpers"

class ArenaRoomManagementFlowTest < ActionDispatch::IntegrationTest
  include ArenaFoundationHelpers
  setup do
    @host, @other = arena_user, arena_user
    @content = Arena::Catalog.create_preview!
    Arena::Catalog.publish!(content: @content, reviewer_reference: SecureRandom.uuid)
    @owner, @foreign = open_session, open_session
    [[@owner,@host],[@foreign,@other]].each do |client,user|
      client.post user_session_path, params: { user: { email: user.email, password: "isolated-arena-password" } }
    end
  end

  test "all own open rooms appear separately even after more than six later results" do
    old = arena_session(@host)
    private_room = arena_session(@other)
    7.times do
      finished = arena_session(@host)
      Arena::Game.command!(actor: @host, session: finished, command: "finish", expected_version: finished.lock_version)
    end
    @owner.get app_arena_path
    assert_equal 200, @owner.response.status
    doc = Nokogiri::HTML(@owner.response.body)
    section = doc.at_css('.arena-owned-rooms')
    assert section
    assert section.at_css("a[href='#{app_arena_session_path(old)}']")
    refute section.at_css("a[href='#{app_arena_session_path(private_room)}']")
    form = section.at_css("form[action='#{command_app_arena_session_path(old)}']")
    assert_equal "finish", form.at_css('[name="command"]')["value"]
    assert_equal old.lock_version.to_s, form.at_css('[name="version"]')["value"]
  end

  test "HTTP creation works with two existing lobbies and preserves the submitted musical configuration" do
    2.times { arena_session(@host) }
    @owner.post app_arena_sessions_path, params: { title: "Outra turma", content_version_id: @content.id, question_count: 2, duration_seconds: 30, prepare_lobby: "1", host_mode: "play" }
    assert_equal 303, @owner.response.status
    assert_equal 3, ArenaSession.where(host: @host).count
    room = ArenaSession.where(host: @host).order(created_at: :desc).first
    assert_equal "Outra turma", room.title
    assert_equal 2, room.arena_rounds.count
    assert_equal "lobby_open", room.state
  end

  test "JSON management protects ownership and version and closes legacy preparations without deleting them" do
    room = arena_session(@host)
    params = { command: "finish", version: room.lock_version, return_to: "arena", host_id: @host.id }
    @foreign.post command_app_arena_session_path(room), params: params, as: :json
    assert_equal 404, @foreign.response.status
    assert_equal "draft", room.reload.state
    @owner.post command_app_arena_session_path(room), params: params.merge(version: room.lock_version + 1), as: :json
    assert_equal 409, @owner.response.status
    @owner.post command_app_arena_session_path(room), params: params, as: :json
    assert_equal 204, @owner.response.status
    assert_equal "cancelled", room.reload.state
    assert ArenaSession.exists?(room.id)
    @owner.get app_arena_path
    refute Nokogiri::HTML(@owner.response.body).at_css('.arena-owned-rooms')
  end
end
