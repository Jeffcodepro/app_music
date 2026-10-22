module ArenaFoundationHelpers
  def arena_user(name = "Participante de teste")
    User.create!(email: "arena-#{SecureRandom.hex(8)}@example.test", password: "isolated-arena-password", full_name: name)
  end

  def arena_grant(user)
    Arena::HostAccess.grant!(user: user, operator_reference: SecureRandom.uuid)
  end

  def arena_session(host)
    Arena::Sessions.create!(actor: host, title: "Sessão sintética")
  end

  def arena_payload
    { "prompt" => "Contrato sintético de quatro alternativas", "options" => [
      { "id" => "a", "label" => "Referência A" }, { "id" => "b", "label" => "Referência B" },
      { "id" => "c", "label" => "Referência C" }, { "id" => "d", "label" => "Referência D" }
    ], "correct_option_id" => "b" }
  end

  def arena_round(session, position: 1)
    snapshot = ArenaQuestionSnapshot.create!(arena_session: session, payload_version: "choice-v1", payload: arena_payload)
    ArenaRound.create!(arena_session: session, arena_question_snapshot: snapshot, position: position)
  end

  def answering_round(session)
    round = arena_round(session)
    %w[lobby_open lobby_locked live].each { |state| session.update!(state: state) }
    round.update!(state: "preparing")
    round.update!(state: "ready")
    round.update!(state: "answering", answer_open_at: 1.minute.ago, deadline_at: 5.minutes.from_now)
    round
  end

  def arena_membership(session, user)
    ArenaMembership.create!(arena_session: session, user: user, nickname: "Alias de teste")
  end
end
