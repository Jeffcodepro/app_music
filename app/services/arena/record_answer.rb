module Arena
  class RecordAnswer
    def self.call(actor:, round:, option_id:, idempotency_key:)
      SchemaIntegrity.verify!
      raise Forbidden, "Authentication required" unless actor&.persisted?
      raise InvalidAnswer, "Attempt UUID required" unless HostAccess::UUID.match?(idempotency_key.to_s)
      actor.with_lock do
        session = ArenaSession.lock.find(round.arena_session_id)
        membership = ArenaMembership.find_by(arena_session_id: session.id, user_id: actor.id)
        raise Forbidden, "Membership required" unless membership
        prior = ArenaAnswer.find_by(arena_membership_id: membership.id, idempotency_key: idempotency_key)
        if prior
          unless prior.arena_round_id == round.id && prior.option_id == option_id
            raise Conflict, "Attempt UUID reused with another payload"
          end
          next Projections.acknowledgement(prior)
        end
        raise Forbidden, "Active membership required" unless membership.status == "active"
        round = ArenaRound.lock.find_by!(id: round.id, arena_session_id: session.id)
        now = DatabaseClock.now
        unless session.state == "live" && round.state == "answering" && round.answer_open_at && round.deadline_at &&
          now >= round.answer_open_at && now < round.deadline_at
          raise InvalidAnswer, "Answer window closed"
        end
        raise InvalidAnswer, "Escuta indisponível nesta rodada. Nenhuma resposta registrada." unless Playback.eligible?(session, round, membership)
        raise InvalidAnswer, "Unknown option" unless round.arena_question_snapshot.option_ids.include?(option_id)
        raise AlreadyAnswered, "A response already exists" if ArenaAnswer.exists?(arena_round_id: round.id, arena_membership_id: membership.id)
        answer = ArenaAnswer.create!(arena_session: session, arena_round: round, arena_membership: membership,
          option_id: option_id, idempotency_key: idempotency_key, accepted_at: now,
          response_elapsed_ms: session.duration_seconds && [[(session.duration_seconds * 1000 - (round.deadline_at - now) * 1000).floor, 0].max, session.duration_seconds * 1000 - 1].min)
        Events.append!(session: session, round: round, actor: actor, kind: "answer_recorded", payload: { "membership_id" => membership.id })
        Projections.acknowledgement(answer)
      end
    end
  end
end
