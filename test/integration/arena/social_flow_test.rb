require "test_helper"
require_relative "../../support/arena_foundation_helpers"

class ArenaSocialFlowTest < ActionDispatch::IntegrationTest
  include ArenaFoundationHelpers

  setup do
    @host, @student, @other = arena_user, arena_user, arena_user
    @content = Arena::Catalog.create_preview!
    Arena::Catalog.publish!(content: @content, reviewer_reference: SecureRandom.uuid)
    @creator, @guest, @foreign = open_session, open_session, open_session
    [[@creator,@host],[@guest,@student],[@foreign,@other]].each do |client,user|
      client.post user_session_path, params: { user: { email: user.email, password: "isolated-arena-password" } }
    end
    @config = { title: "Palco aberto", content_version_id: @content.id, question_count: 2, duration_seconds: 10,
      host_avatar: "fox", host_nickname: "Maestro", capacity: 3, visibility: "public" }
  end

  test "legacy confirmation endpoints require identity while the web entry opens a lobby" do
    @creator.get app_arena_path
    assert_equal 200, @creator.response.status
    doc = Nokogiri::HTML(@creator.response.body)
    assert_empty doc.css('input[name="host_avatar"]')
    assert_empty doc.css('input[name="avatar_id"]')
    assert_equal doc.css('[id]').size, doc.css('[id]').map { |node| node['id'] }.uniq.size
    assert_no_difference "ArenaSession.count" do
      @creator.post app_arena_sessions_path, params: @config.except(:host_avatar)
      assert_equal 422, @creator.response.status
    end
    @creator.post app_arena_sessions_path, params: @config.merge(scoring_version: "accuracy-1000-v1", host_id: @other.id)
    assert_equal 303, @creator.response.status
    room = ArenaSession.find_by!(host: @host)
    assert_equal "speed-streak-v1", room.scoring_version
    assert_equal "fox", room.arena_memberships.sole.avatar_id
    assert_no_difference "ArenaMembership.count" do
      @guest.get app_arena_path(public_session_id: room.id)
      assert_equal 303, @guest.response.status
      @guest.follow_redirect!
      assert_equal 200, @guest.response.status
      assert_includes @guest.response.body, "Palco aberto"
      @guest.post join_app_arena_path, params: { public_session_id: room.id, nickname: "Sabiá" }
      assert_equal 422, @guest.response.status
    end
    @guest.post join_app_arena_path, params: { public_session_id: room.id, nickname: "Sabiá", avatar_id: "cat" }
    assert_equal 303, @guest.response.status
    @creator.get app_arena_session_path(room, format: :json)
    assert_equal ["fox","cat"], @creator.response.parsed_body.fetch("roster").map { |row| row["avatar_id"] }
    @guest.get app_arena_session_path(room, format: :json)
    refute_match(/membership_id|user_id|invite|ciphertext|correct_option_id/, @guest.response.body)
    refute @guest.response.parsed_body.fetch("roster").any? { |row| row.key?("id") || row["removable"] }
  end

  test "public directory excludes private full started expired rooms and preserves failed identity" do
    @creator.post app_arena_sessions_path, params: @config.merge(capacity: 2)
    room = ArenaSession.find_by!(host: @host)
    @guest.post join_app_arena_path, params: { public_session_id: room.id, nickname: "Sabiá", avatar_id: "cat" }
    @foreign.post join_app_arena_path, params: { public_session_id: room.id, nickname: "Canário", avatar_id: "robot" }
    assert_equal 422, @foreign.response.status
    assert_includes @foreign.response.body, "A sala lotou"
    assert_equal 2, room.arena_memberships.count
    @foreign.get app_arena_path
    directory = Nokogiri::HTML(@foreign.response.body).at_css('.arena-open-rooms').to_html
    refute_includes directory, room.title
    refute_includes directory, Arena::Invites.code(room)
    anonymous = open_session
    anonymous.get app_arena_path
    assert_equal 302, anonymous.response.status
  end

  test "host removes confirmed participant only in own lobby and rejected member cannot return" do
    @creator.post app_arena_sessions_path, params: @config
    room = ArenaSession.find_by!(host: @host)
    @guest.post join_app_arena_path, params: { public_session_id: room.id, nickname: "Sabiá", avatar_id: "cat" }
    member = room.arena_memberships.find_by!(user: @student)
    route = remove_member_app_arena_session_path(room, member)
    @foreign.post route, params: { version: room.reload.lock_version }
    assert_equal 404, @foreign.response.status
    @creator.get app_arena_session_path(room)
    assert_includes @creator.response.body, "Confirmar remoção"
    @creator.post route, params: { version: room.reload.lock_version }
    assert_equal 303, @creator.response.status
    assert_equal "removed", member.reload.status
    @guest.get app_arena_session_path(room, format: :json)
    assert_equal 404, @guest.response.status
    @guest.post join_app_arena_path, params: { code: Arena::Invites.code(room), nickname: "Voltei", avatar_id: "robot" }
    assert_equal 422, @guest.response.status
    @creator.post command_app_arena_session_path(room), params: { command: "start", version: room.reload.lock_version }
    @creator.post route, params: { version: room.reload.lock_version }
    assert_equal 422, @creator.response.status
  end
end
