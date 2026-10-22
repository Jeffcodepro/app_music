require "test_helper"
require "timeout"
require_relative "../../support/arena_foundation_helpers"

class ArenaFoundationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  include ArenaFoundationHelpers

  setup do
    @host, @student = arena_user, arena_user
    @grant = arena_grant(@host)
    @session = arena_session(@host)
  end

  teardown do
    [@student, @host].each { |user| user.destroy! if User.exists?(user.id) }
  end

  def race(*operations)
    ready, release = Queue.new, Queue.new
    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          release.pop
          begin
            operation.call
          rescue Arena::Forbidden, Arena::Conflict, Arena::InvalidAnswer => error
            error.class
          end
        end
      end
    end
    pids = operations.map { ready.pop }
    assert_equal operations.size, pids.uniq.size
    operations.size.times { release << true }
    threads.map { |thread| Timeout.timeout(10) { thread.value } }
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
  end

  test "simultaneous same-key submissions persist once" do
    round = answering_round(@session)
    member = arena_membership(@session, @student)
    key = SecureRandom.uuid
    operation = -> { Arena::RecordAnswer.call(actor: User.find(@student.id), round: ArenaRound.find(round.id), option_id: "b", idempotency_key: key) }
    results = race(operation, operation)
    assert_equal results.first, results.last
    assert_equal 1, ArenaAnswer.where(arena_membership: member).count
    assert_equal [1, 2], @session.arena_events.order(:sequence).pluck(:sequence)
  end

  test "conflicting payloads cannot reuse a token concurrently" do
    round = answering_round(@session)
    member = arena_membership(@session, @student)
    key = SecureRandom.uuid
    results = race(*%w[a b].map { |option| -> { Arena::RecordAnswer.call(actor: User.find(@student.id), round: ArenaRound.find(round.id), option_id: option, idempotency_key: key) } })
    assert_equal 1, results.count { |result| result == Arena::Conflict }
    assert_equal 1, results.count { |result| result.is_a?(Hash) && result[:accepted] }
    assert_equal 1, ArenaAnswer.where(arena_membership: member).count
  end

  test "separate participants allocate a contiguous event sequence" do
    second = arena_user
    round = answering_round(@session)
    [@student, second].each { |user| arena_membership(@session, user) }
    results = race(*[@student.id, second.id].map { |id| -> { Arena::RecordAnswer.call(actor: User.find(id), round: ArenaRound.find(round.id), option_id: "b", idempotency_key: SecureRandom.uuid) } })
    assert results.all? { |result| result.is_a?(Hash) && result[:accepted] }
    assert_equal [1, 2, 3], @session.arena_events.order(:sequence).pluck(:sequence)
  ensure
    second&.destroy! if second && User.exists?(second.id)
  end

  test "historical grant revocation serializes but no longer blocks an account from creating" do
    ready = Queue.new
    worker = nil
    @host.with_lock do
      worker = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          ready << connection.select_value("SELECT pg_backend_pid()")
          begin
            arena_session(User.find(@host.id))
          rescue Arena::Forbidden
            :forbidden
          end
        end
      end
      pid = ready.pop
      Timeout.timeout(5) do
        until ActiveRecord::Base.uncached { ActiveRecord::Base.connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0") }
          sleep 0.005
        end
      end
      Arena::HostAccess.revoke!(grant: @grant, operator_reference: SecureRandom.uuid)
    end
    assert_instance_of ArenaSession, Timeout.timeout(10) { worker.value }
    assert_equal 2, ArenaSession.where(host: @host).count
    assert @grant.reload.revoked_at
  ensure
    worker&.kill if worker&.alive?
  end

  test "host removal and answer serialize without duplicate data or partial anonymity" do
    round = answering_round(@session)
    membership = arena_membership(@session, @student)
    results = race(-> { Arena::RecordAnswer.call(actor: User.find(@student.id), round: ArenaRound.find(round.id), option_id: "b", idempotency_key: SecureRandom.uuid) },
      -> { User.find(@host.id).destroy!; :removed })
    assert_includes results, :removed
    assert_equal "cancelled", @session.reload.state
    assert_nil @session.host_id
    assert_equal "void", round.reload.state
    assert_operator ArenaAnswer.where(arena_membership: membership).count, :<=, 1
    assert @session.arena_events.where(kind: "account_removed").exists?
  end
end
