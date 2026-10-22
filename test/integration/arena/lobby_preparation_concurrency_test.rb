require "test_helper"
require "timeout"
require_relative "../../support/arena_foundation_helpers"

class ArenaLobbyPreparationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  include ArenaFoundationHelpers

  setup do
    @host,@one,@two = arena_user,arena_user,arena_user
    reference = Arena::Catalog.create_preview!
    content = ArenaContentVersion.create!(code: "lobby-race-#{SecureRandom.hex(8)}", revision: 1, title: "Referência de concorrência", status: "published",
      body: reference.body, content_digest: reference.content_digest, source_digest: reference.source_digest, reviewer_reference: SecureRandom.uuid, reviewed_at: Time.current)
    @room = Arena::Game.create!(actor: @host, content_version: content, title: "Prontos", question_count: 1, duration_seconds: 10, experience: "party", visibility: "public", capacity: 2)
    @grants = [@one,@two].to_h { |user| [user.id,Arena::LobbyAccess.prepare!(actor: user, public_session_id: @room.id).last] }
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
          rescue Arena::Unavailable, Arena::Forbidden => error
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

  def confirm(user)
    Arena::LobbyAccess.confirm!(actor: User.find(user.id), session: ArenaSession.find(@room.id), grant: @grants.fetch(user.id), nickname: "Sabiá", avatar_id: "cat")
  end

  test "two tabs confirm once with only one readiness event" do
    before = ArenaEvent.uncached { @room.arena_events.count }
    result = race(-> { confirm(@one) },-> { confirm(@one) })
    assert_equal 1, result.map(&:id).uniq.size
    assert_equal 2, ArenaMembership.uncached { @room.arena_memberships.count }
    assert_equal before + 1, ArenaEvent.uncached { @room.arena_events.count }
  end

  test "two prepared players cannot confirm the same final place" do
    result = race(-> { confirm(@one) },-> { confirm(@two) })
    assert_equal 1, result.count { |item| item.is_a?(ArenaMembership) }
    assert_equal 2, ArenaMembership.uncached { @room.arena_memberships.where(status: "active").count }
  end
end
