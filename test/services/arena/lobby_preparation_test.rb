require "test_helper"
require_relative "../../support/arena_foundation_helpers"

class ArenaLobbyPreparationTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers

  setup do
    @host, @guest = arena_user, arena_user
    content = Arena::Catalog.create_preview!
    @room = Arena::Game.create!(actor: @host, content_version: content, title: "Lobby da banda", question_count: 1, duration_seconds: 10,
      technical_preview: true, experience: "party", defer_host_identity: true, visibility: "public", capacity: 2)
  end

  def ready_host
    Arena::LobbyAccess.confirm!(actor: @host, session: @room, grant: nil, nickname: "Maestro", avatar_id: "fox")
  end

  test "host first opens lobby then confirms identity before sharing discovery or start" do
    assert_empty @room.arena_memberships
    state = Arena::SessionView.call(actor: @host, session: @room)
    assert state[:identity_required]
    refute state.key?(:invite)
    refute_includes Arena::Directory.rows.map { |row| row[:id] }, @room.id
    assert_raises(Arena::InvalidTransition) { Arena::Game.command!(actor: @host, session: @room, command: "start", expected_version: @room.reload.lock_version) }
    assert_raises(Arena::Unavailable) { Arena::Join.call(actor: @guest, code: Arena::Invites.code(@room), nickname: "Sabiá", avatar_id: "cat") }
    member = ready_host
    assert_equal "fox", member.avatar_id
    assert Arena::SessionView.call(actor: @host, session: @room)[:invite]
    assert_includes Arena::Directory.rows.map { |row| row[:id] }, @room.id
  end

  test "preparation admits no player and reveals only lobby summary" do
    ready_host
    before = [ArenaMembership.count,ArenaEvent.count,@room.reload.event_sequence]
    room, grant = Arena::LobbyAccess.prepare!(actor: @guest, code: Arena::Invites.code(@room))
    assert_equal @room.id, room.id
    state = Arena::LobbyAccess.view!(actor: @guest, session: room, grant: grant)
    assert state[:identity_required]
    assert_equal @room.title, state[:title]
    refute_match(/invite|roster|options|correct|question|ranking|ciphertext|Maestro/, state.to_json)
    assert_equal before, [ArenaMembership.count,ArenaEvent.count,@room.reload.event_sequence]
    refute Arena::SessionPolicy.new(@guest, room).participate?
    assert_raises(Arena::Forbidden) { Arena::SessionView.call(actor: @guest, session: room) }
    assert_raises(Arena::Forbidden) { Arena::LobbyAccess.view!(actor: @guest, session: room, grant: nil) }
  end

  test "confirmation is unique and one readiness event follows the completed identity" do
    ready_host
    _, grant = Arena::LobbyAccess.prepare!(actor: @guest, public_session_id: @room.id)
    assert_no_difference ["ArenaMembership.count","ArenaEvent.count"] do
      assert_raises(Arena::Unavailable) { Arena::LobbyAccess.confirm!(actor: @guest, session: @room, grant: grant, nickname: "Sabiá", avatar_id: nil) }
    end
    assert_difference ["ArenaMembership.count","ArenaEvent.count"], 1 do
      @member = Arena::LobbyAccess.confirm!(actor: @guest, session: @room, grant: grant, nickname: "Sabiá", avatar_id: "cat")
    end
    assert_no_difference ["ArenaMembership.count","ArenaEvent.count"] do
      assert_equal @member, Arena::LobbyAccess.confirm!(actor: @guest, session: @room, grant: nil, nickname: "Outro", avatar_id: "robot")
    end
    assert_equal "Sabiá", @member.reload.nickname
    assert_equal "cat", @member.avatar_id
  end

  test "preparation permission is bound to account room invitation time and removal" do
    ready_host
    _, grant = Arena::LobbyAccess.prepare!(actor: @guest, code: Arena::Invites.code(@room))
    [grant.merge("user_id" => @host.id),grant.merge("room_id" => SecureRandom.uuid),grant.merge("expires_at" => 1.hour.ago.to_i),grant.merge("invite_digest" => "0" * 64)].each do |invalid|
      assert_raises(Arena::Forbidden) { Arena::LobbyAccess.confirm!(actor: @guest, session: @room, grant: invalid, nickname: "Sabiá", avatar_id: "cat") }
    end
    Arena::Game.command!(actor: @host, session: @room, command: "renew_invite", expected_version: @room.reload.lock_version)
    assert_raises(Arena::Forbidden) { Arena::LobbyAccess.confirm!(actor: @guest, session: @room, grant: grant, nickname: "Sabiá", avatar_id: "cat") }
    _, grant = Arena::LobbyAccess.prepare!(actor: @guest, code: Arena::Invites.code(@room.reload))
    member = Arena::LobbyAccess.confirm!(actor: @guest, session: @room, grant: grant, nickname: "Sabiá", avatar_id: "cat")
    Arena::Lobby.remove!(actor: @host, session: @room, membership_id: member.id, expected_version: @room.reload.lock_version)
    assert_raises(Arena::Forbidden) { Arena::LobbyAccess.view!(actor: @guest, session: @room, grant: grant) }
    assert_raises(Arena::Unavailable) { Arena::LobbyAccess.confirm!(actor: @guest, session: @room, grant: grant, nickname: "Voltei", avatar_id: "cat") }
  end
end
