require "uri"
module Arena
  class ScoreShare
    def self.call(actor:, session:)
      raise Forbidden unless actor&.persisted?
      raise InvalidTransition unless ArenaSession::TERMINAL.include?(session.state)
      member = session.arena_memberships.find_by(user: actor, status: %w[active left])
      raise Forbidden unless member
      own = Scoreboard.rows(session).find { |row| row[:membership_id] == member.id }
      raise Forbidden unless own
      position = own[:place] ? " Minha posição: #{own[:place]}º." : " Sem classificação: nenhuma rodada pôde ser avaliada."
      text = "Fiz #{own[:points]} pontos e acertei #{own[:correct]} de #{own[:total]} questões na Arena Musical do AppMusic!#{position}"
      { text: text, whatsapp: "https://wa.me/?text=#{URI.encode_www_form_component(text)}", email: "mailto:?#{URI.encode_www_form(subject: 'Meu resultado na Arena Musical', body: text)}" }
    end
  end
end
