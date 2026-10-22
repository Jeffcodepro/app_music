module Arena
  class Events
    # Caller owns the session row lock and transaction.
    def self.append!(session:, actor:, kind:, payload:, round: nil)
      raise ArgumentError, "A transaction is required" unless ArenaSession.connection.transaction_open?
      session.event_sequence += 1
      session.save!
      ArenaEvent.create!(arena_session: session, arena_round: round, actor: actor, sequence: session.event_sequence,
        session_version: session.lock_version, kind: kind, payload: payload)
    end
  end
end
