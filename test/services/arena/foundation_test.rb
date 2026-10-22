require "test_helper"
require_relative "../../support/arena_foundation_helpers"

class ArenaFoundationTest < ActiveSupport::TestCase
  include ArenaFoundationHelpers

  setup do
    @host, @student, @other = Array.new(3) { arena_user }
    @grant = arena_grant(@host)
    @session = arena_session(@host)
  end

  test "any registered account can create independently of grants and subscription" do
    assert_nil @host.plan
    assert_equal @host, @session.host
    assert_equal @student, arena_session(@student).host
    @student.update!(plan: "maestro")
    assert_equal @student, arena_session(@student).host
    assert_raises(ArgumentError) { Arena::Sessions.create!(actor: @student, title: "forged", host_id: @host.id) }
    assert_not Arena::SessionPolicy.new(nil, @session).create?
  end

  test "revocation is irreversible and regrant preserves history" do
    Arena::HostAccess.revoke!(grant: @grant, operator_reference: SecureRandom.uuid)
    assert arena_session(@host).persisted?
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaHostGrant.transaction(requires_new: true) { @grant.update_columns(revoked_at: nil) }
    end
    replacement = arena_grant(@host)
    assert_not_equal @grant.id, replacement.id
    assert_equal 2, ArenaHostGrant.where(user: @host).count
    assert arena_session(@host).persisted?
    assert_raises(ActiveRecord::RecordInvalid) { arena_grant(@host) }
  end

  test "owner and current version are verified before state mutation or event" do
    arena_grant(@other)
    assert_raises(Arena::Forbidden) do
      Arena::Sessions.transition!(actor: @other, session: @session, to: "lobby_open", expected_version: @session.lock_version)
    end
    old_version = @session.lock_version
    Arena::Sessions.transition!(actor: @host, session: @session, to: "lobby_open", expected_version: old_version)
    assert_raises(Arena::Conflict) do
      Arena::Sessions.transition!(actor: @host, session: @session, to: "cancelled", expected_version: old_version)
    end
    assert_equal "lobby_open", @session.reload.state
    assert_equal [1, 2], @session.arena_events.order(:sequence).pluck(:sequence)
    assert_raises(Arena::InvalidTransition) do
      Arena::Sessions.transition!(actor: @host, session: @session, to: "completed", expected_version: @session.lock_version)
    end
    assert_equal 2, @session.arena_events.count
  end

  test "a session mutation and event roll back together" do
    before = @session.attributes.slice("state", "event_sequence", "lock_version")
    assert_raises(ActiveRecord::RecordInvalid) do
      @session.with_lock do
        @session.state = "lobby_open"
        Arena::Events.append!(session: @session, actor: @host, kind: "unsupported", payload: {})
      end
    end
    assert_equal before, @session.reload.attributes.slice("state", "event_sequence", "lock_version")
    assert_equal 1, @session.arena_events.count
  end

  test "snapshot is immutable in SQL and public projection strips private nested fields" do
    round = arena_round(@session)
    snapshot = round.arena_question_snapshot
    assert_equal 64, snapshot.payload_digest.length
    public_data = Arena::Projections.question(snapshot)
    refute_includes public_data.to_json, "correct_option_id"
    assert_equal %w[id label], public_data.fetch(:options).first.keys.map(&:to_s).sort
    snapshot.payload["options"][0]["correct"] = true
    snapshot.payload["internal"] = { "answer_key" => "b" }
    refute_match(/answer_key|correct/, Arena::Projections.question(snapshot).to_json)
    assert_raises(Arena::PrivatePayload) { snapshot.as_json }
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaQuestionSnapshot.transaction(requires_new: true) { ArenaQuestionSnapshot.where(id: snapshot.id).update_all(payload: arena_payload.merge("correct_option_id" => "a")) }
    end
    assert_equal "b", snapshot.reload.payload.fetch("correct_option_id")
  end

  test "snapshot and answer foreign keys prevent crossing sessions even with SQL" do
    other_session = arena_session(@host)
    round = arena_round(@session)
    other_round = arena_round(other_session)
    membership = arena_membership(other_session, @student)
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaRound.transaction(requires_new: true) do
        ArenaRound.insert_all!([{ id: SecureRandom.uuid, arena_session_id: @session.id, arena_question_snapshot_id: other_round.arena_question_snapshot_id,
          position: 2, state: "queued", lock_version: 0, created_at: Time.current, updated_at: Time.current }])
      end
    end
    local_membership = arena_membership(@session, @student)
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaAnswer.transaction(requires_new: true) do
        ArenaAnswer.insert_all!([{ id: SecureRandom.uuid, arena_session_id: @session.id, arena_round_id: other_round.id,
          arena_membership_id: local_membership.id, option_id: "a", idempotency_key: SecureRandom.uuid,
          accepted_at: Time.current, created_at: Time.current }])
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaEvent.transaction(requires_new: true) do
        ArenaEvent.insert_all!([{ id: SecureRandom.uuid, arena_session_id: @session.id, arena_round_id: other_round.id,
          sequence: 99, session_version: 0, kind: "round_state_changed", payload: { state: "queued" }, created_at: Time.current }])
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaAnswer.transaction(requires_new: true) do
        ArenaAnswer.insert_all!([{ id: SecureRandom.uuid, arena_session_id: @session.id, arena_round_id: round.id,
          arena_membership_id: membership.id, option_id: "a", idempotency_key: SecureRandom.uuid,
          accepted_at: Time.current, created_at: Time.current }])
      end
    end
  end

  test "only one round can be open including paused rounds" do
    first, second = arena_round(@session), arena_round(@session, position: 2)
    first.update!(state: "preparing")
    first.update!(state: "paused", paused_from: "preparing", remaining_ms: 0)
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaRound.transaction(requires_new: true) { second.update_columns(state: "ready") }
    end
    assert_raises(ActiveRecord::RecordInvalid) { first.update!(state: "results") }
  end

  test "recording answers is idempotent private and separated from individual XP" do
    round = answering_round(@session)
    arena_membership(@session, @student)
    key = SecureRandom.uuid
    before = [ExerciseAttempt.count, ExerciseAssignment.count, StudyActivity.count, StudyActivity.sum(:xp_earned)]
    ack = Arena::RecordAnswer.call(actor: @student, round: round, option_id: "b", idempotency_key: key)
    assert_equal ack, Arena::RecordAnswer.call(actor: @student, round: round, option_id: "b", idempotency_key: key)
    refute_match(/correct|points|score/, ack.to_json)
    assert_raises(Arena::Conflict) { Arena::RecordAnswer.call(actor: @student, round: round, option_id: "a", idempotency_key: key) }
    assert_raises(Arena::AlreadyAnswered) { Arena::RecordAnswer.call(actor: @student, round: round, option_id: "a", idempotency_key: SecureRandom.uuid) }
    assert_equal 1, ArenaAnswer.where(arena_session: @session).count
    assert_equal before, [ExerciseAttempt.count, ExerciseAssignment.count, StudyActivity.count, StudyActivity.sum(:xp_earned)]
  end

  test "invalid membership option window and malformed identity cannot record answers" do
    round = answering_round(@session)
    assert_raises(Arena::Forbidden) { Arena::RecordAnswer.call(actor: @student, round: round, option_id: "b", idempotency_key: SecureRandom.uuid) }
    arena_membership(@session, @student)
    assert_raises(Arena::InvalidAnswer) { Arena::RecordAnswer.call(actor: @student, round: round, option_id: "unknown", idempotency_key: SecureRandom.uuid) }
    assert_raises(Arena::InvalidAnswer) { Arena::RecordAnswer.call(actor: @student, round: round, option_id: "b", idempotency_key: "bad") }
    round.update_columns(deadline_at: 1.second.ago, answer_open_at: 2.minutes.ago)
    assert_raises(Arena::InvalidAnswer) { Arena::RecordAnswer.call(actor: @student, round: round, option_id: "b", idempotency_key: SecureRandom.uuid) }
    assert_equal 0, ArenaAnswer.where(arena_session: @session).count
  end

  test "account removal anonymizes history closes owned sessions and preserves answers" do
    round = answering_round(@session)
    membership = arena_membership(@session, @student)
    Arena::RecordAnswer.call(actor: @student, round: round, option_id: "b", idempotency_key: SecureRandom.uuid)
    answer_id = ArenaAnswer.where(arena_session: @session).sole.id
    old_sequence = @session.reload.event_sequence
    @student.destroy!
    assert_nil membership.reload.user_id
    assert_equal "removed", membership.status
    assert_equal "Participante removido", membership.nickname
    assert_equal answer_id, ArenaAnswer.where(arena_session: @session).sole.id
    assert_equal old_sequence + 1, @session.reload.event_sequence
    @host.destroy!
    assert_nil @session.reload.host_id
    assert_equal "cancelled", @session.state
    assert_equal "void", round.reload.state
    assert_nil @grant.reload.user_id
    assert @grant.revoked_at
    assert @session.arena_events.where(actor_id: nil).exists?
  end

  test "null pause and resume origins fail SQL constraints" do
    round = arena_round(@session)
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaRound.transaction(requires_new: true) { ArenaRound.where(id: round.id).update_all(state: "paused", paused_from: nil, remaining_ms: 0) }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaSession.transaction(requires_new: true) { ArenaSession.where(id: @session.id).update_all(state: "interrupted", resume_from: nil) }
    end
  end

  test "events do not accept states from another domain or private nested fields" do
    [["session_created", "void"], ["session_state_changed", "answering"], ["round_state_changed", "draft"]].each do |kind, state|
      event = ArenaEvent.new(arena_session: @session, sequence: 99, session_version: 1, kind: kind, payload: { "state" => state })
      refute event.valid?
    end
    round = arena_round(@session)
    snapshot = round.arena_question_snapshot
    snapshot.payload["options"][0]["label"] = { "answer_key" => "b" }
    assert_raises(Arena::PrivatePayload) { Arena::Projections.question(snapshot) }
  end

  test "active round coordinated transitions are refused rather than partially applied" do
    round = answering_round(@session)
    @session.reload
    version = @session.lock_version
    %w[paused interrupted completed cancelled].each do |state|
      assert_raises(Arena::InvalidTransition) { Arena::Sessions.transition!(actor: @host, session: @session, to: state, expected_version: version) }
    end
    assert_equal "live", @session.reload.state
    assert_equal "answering", round.reload.state
  end

  test "private records cannot serialize directly or through an association include" do
    round = answering_round(@session)
    arena_membership(@session, @student)
    Arena::RecordAnswer.call(actor: @student, round: round, option_id: "b", idempotency_key: SecureRandom.uuid)
    [round.arena_question_snapshot, ArenaAnswer.where(arena_session: @session).sole, @session.arena_events.first].each do |record|
      assert_raises(Arena::PrivatePayload) { record.serializable_hash }
      assert_raises(Arena::PrivatePayload) { record.as_json }
    end
    assert_raises(Arena::PrivatePayload) { round.as_json(include: :arena_question_snapshot) }
    assert_raises(Arena::PrivatePayload) { @session.as_json(include: :arena_answers) }
    assert_raises(Arena::PrivatePayload) { @session.as_json(include: :arena_events) }
  end

  test "account removal refuses missing protection before deleting dependencies" do
    Arena::HostAccess.revoke!(grant: @grant, operator_reference: SecureRandom.uuid)
    @session.update!(state: "cancelled")
    @host.daily_visits.create!(visited_on: Date.current)
    before = @session.attributes
    User.transaction(requires_new: true) do
      User.connection.execute("ALTER TABLE users DISABLE TRIGGER arena_account_removal")
      assert_raises(Arena::SchemaIntegrity::MissingProtection) { @host.destroy! }
      assert User.exists?(@host.id)
      assert_equal 1, @host.daily_visits.count
      assert_equal before, @session.reload.attributes
      assert_equal @host.id, @grant.reload.user_id
      raise ActiveRecord::Rollback
    end
    assert Arena::SchemaIntegrity.verify!
  end

  test "membership uniqueness and immutable accepted history survive direct SQL writes" do
    round = answering_round(@session)
    membership = arena_membership(@session, @student)
    assert_raises(ActiveRecord::StatementInvalid) do
      ArenaMembership.transaction(requires_new: true) do
        ArenaMembership.insert_all!([{ id: SecureRandom.uuid, arena_session_id: @session.id, user_id: @student.id,
          nickname: "Duplicate", status: "active", created_at: Time.current, updated_at: Time.current }])
      end
    end
    key = SecureRandom.uuid
    Arena::RecordAnswer.call(actor: @student, round: round, option_id: "b", idempotency_key: key)
    other_round = arena_round(@session, position: 2)
    assert_raises(Arena::Conflict) { Arena::RecordAnswer.call(actor: @student, round: other_round, option_id: "b", idempotency_key: key) }
    [ArenaAnswer.where(arena_membership: membership), @session.arena_events, ArenaQuestionSnapshot.where(id: round.arena_question_snapshot_id)].each do |records|
      assert_raises(ActiveRecord::StatementInvalid) { records.klass.transaction(requires_new: true) { records.delete_all } }
    end
    assert_equal 1, ArenaAnswer.where(arena_membership: membership).count
  end

  test "malformed four-choice snapshots cannot be persisted" do
    [
      ->(payload) { payload["correct_option_id"] = "missing" },
      ->(payload) { payload["options"].pop },
      ->(payload) { payload["options"][1]["id"] = "a" },
      ->(payload) { payload["options"][1]["label"] = " REFERÊNCIA A " },
      ->(payload) { payload["options"][0]["label"] = { "answer_key" => "b" } }
    ].each do |corrupt|
      payload = arena_payload
      corrupt.call(payload)
      assert_raises(ActiveRecord::RecordInvalid) do
        ArenaQuestionSnapshot.create!(arena_session: @session, payload_version: "choice-v1", payload: payload)
      end
    end
  end

  test "preexisting legacy deletion restriction rolls back all new anonymization" do
    @host.study_activities.create!(area: "leitura", xp_earned: 6, minutes_practiced: 1, occurred_on: Date.current)
    User.connection.execute(<<~SQL)
      INSERT INTO arena_rooms(host_id,title,room_code,theme,question_kind,question_count,
        question_duration_seconds,difficulty,advance_mode,created_at,updated_at) VALUES
        (#{Integer(@host.id)},'Synthetic legacy restriction','#{SecureRandom.hex(8)}','synthetic','visual',1,30,'fixture','manual',now(),now())
    SQL
    original = @session.attributes
    assert_raises(ActiveRecord::InvalidForeignKey) do
      User.transaction(requires_new: true) { @host.destroy! }
    end
    assert User.exists?(@host.id)
    assert_equal 1, StudyActivity.where(user: @host).count
    assert_equal original, @session.reload.attributes
    assert_nil @grant.reload.revoked_at
    assert_equal @host.id, @grant.user_id
  end
end
