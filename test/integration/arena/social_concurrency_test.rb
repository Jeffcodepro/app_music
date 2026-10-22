require "test_helper"
require "timeout"
require_relative "../../support/arena_foundation_helpers"

class ArenaSocialConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  include ArenaFoundationHelpers

  setup do
    @host, @one, @two = arena_user, arena_user, arena_user
    reference = Arena::Catalog.create_preview!
    @content = ArenaContentVersion.create!(code: "social-race-#{SecureRandom.hex(8)}", revision: 1, title: "Referência de concorrência", status: "published",
      body: reference.body, content_digest: reference.content_digest, source_digest: reference.source_digest, reviewer_reference: SecureRandom.uuid, reviewed_at: Time.current)
    @room = Arena::Game.create!(actor: @host, content_version: @content, title: "Última vaga", question_count: 2, duration_seconds: 10,
      experience: "party", host_avatar: "fox", capacity: 2, visibility: "public", scoring_version: "speed-streak-v1")
  end
  teardown { [@host,@one,@two].each { |user| user.destroy! if User.exists?(user.id) } }

  def race(*operations)
    ready,release = Queue.new,Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          release.pop
          begin
            operation.call
          rescue Arena::Unavailable, Arena::InvalidTransition, Arena::Conflict => error
            error.class
          end
        end
      end
    end
    assert_equal operations.size, operations.map { Timeout.timeout(5) { ready.pop } }.uniq.size
    operations.size.times { release << true }
    threads.map { |thread| Timeout.timeout(10) { thread.value } }
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
  end

  test "two public entrants competing for last place cannot exceed capacity" do
    results = race(*[@one,@two].map { |user| -> { Arena::Join.call(actor: User.find(user.id), public_session_id: @room.id, nickname: "Jogador", avatar_id: "cat") } })
    assert_equal 1, results.count { |result| result.is_a?(ArenaMembership) }
    assert_equal 2, ArenaMembership.uncached { @room.arena_memberships.where(status: "active").count }
    refute_includes Arena::Directory.rows.map { |row| row[:id] }, @room.id
  end

  test "removal and start serialize without deleting participation history" do
    member = Arena::Join.call(actor: @one, public_session_id: @room.id, nickname: "Sabiá", avatar_id: "owl")
    version = @room.reload.lock_version
    results = race(-> { Arena::Lobby.remove!(actor: User.find(@host.id), session: ArenaSession.find(@room.id), membership_id: member.id, expected_version: version) },
      -> { Arena::Game.command!(actor: User.find(@host.id), session: ArenaSession.find(@room.id), command: "start", expected_version: version) })
    assert_equal 2, ArenaMembership.uncached { @room.arena_memberships.count }
    if member.reload.status == "removed"
      assert_equal "lobby_open", @room.reload.state
      assert_includes results, Arena::Conflict
    else
      assert_equal "live", @room.reload.state
      assert_includes results, Arena::Conflict
    end
  end

  test "concurrent starts compete for the final operational slot rather than exceeding the limit" do
    rooms = 2.times.map do
      Arena::Game.create!(actor: @host, content_version: @content, title: "Outro lobby", question_count: 1,
        duration_seconds: 10, experience: "party", host_avatar: "cat")
    end
    Arena::Game.command!(actor: @host, session: @room, command: "start", expected_version: @room.lock_version)
    results = race(*rooms.map do |room|
      -> { Arena::Game.command!(actor: User.find(@host.id), session: ArenaSession.find(room.id), command: "start", expected_version: room.lock_version) }
    end)
    assert_equal 1, results.count { |result| result.is_a?(ArenaSession) }
    assert_includes results, Arena::Unavailable
    assert_equal 2, ArenaSession.uncached { ArenaSession.where(host: @host, state: ArenaSession::IN_PROGRESS).count }
    assert_equal 1, ArenaSession.where(id: rooms.map(&:id), state: "lobby_open").count
  end
end
