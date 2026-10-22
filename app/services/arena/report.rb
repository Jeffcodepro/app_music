require "csv"

module Arena
  # Observations from this game, never a diagnosis of the student's mastery.
  class Report
    TYPES = { "note_name" => "Nome da nota", "accidental" => "Nota e acidente", "key_signature" => "Armadura maior" }.freeze
    OUTCOMES = { "correct" => "Acertou", "incorrect" => "Errou", "unanswered" => "Sem resposta", "technical" => "Escuta indisponível · não avaliada" }.freeze

    def self.call(actor:, session:)
      SchemaIntegrity.verify!
      options = ArenaSession.connection.transaction_open? ? {} : { isolation: :repeatable_read }
      ArenaSession.uncached do
        ArenaSession.transaction(**options) do
          room = ArenaSession.find(session.id)
          raise Forbidden unless SessionPolicy.new(actor, room).control?
          raise InvalidTransition, "O relatório fica disponível ao encerrar o jogo." unless ArenaSession::TERMINAL.include?(room.state)
          rounds = room.arena_rounds.where(state: "results").order(:position).includes(:arena_question_snapshot).to_a
          answers = ArenaAnswer.where(arena_round_id: rounds.map(&:id)).index_by { |answer| [answer.arena_membership_id,answer.arena_round_id] }
          scores = Scoreboard.rows(room).index_by { |row| row[:membership_id] }
          questions = rounds.map do |round|
            snapshot = round.arena_question_snapshot
            shown = Projections.question(snapshot)
            entry = snapshot.payload["entry"]
            exercise = entry ? entry.fetch("exercise") : snapshot.payload.fetch("exercise", {})
            correct_choice = snapshot.payload.fetch("options").find { |option| option["id"] == snapshot.payload.fetch("correct_option_id") }
            correct = option_label(snapshot.payload, correct_choice)
            responses = answers.values.select { |answer| answer.arena_round_id == round.id }
            { position: round.position, prompt: shown[:prompt], svg: shown[:svg] || correct_choice["svg"],
              topic: entry ? "#{MusicContent::AREAS.fetch(entry["area"])} · #{MusicContent::KINDS.fetch(entry["kind"])}" : TYPES.fetch(exercise["question_type"], "Questão musical"), level: entry ? "Nível #{entry["level"]}" : exercise.fetch("season_label", "Não informado"),
              clef: exercise.fetch("clef_label", "Não se aplica"), correct_label: correct,
              responses: responses.size, incorrect: responses.count { |answer| answer.option_id != snapshot.payload.fetch("correct_option_id") } }
          end
          players = room.arena_memberships.order(:created_at,:id).filter_map do |member|
            score = scores[member.id]
            next unless score
            next if member.status == "removed" && answers.keys.none? { |key| key.first == member.id }
            details = rounds.each_with_index.map do |round,index|
              answer = answers[[member.id,round.id]]
              payload = round.arena_question_snapshot.payload
              outcome = !Playback.eligible?(room, round, member) ? "technical" : answer.nil? ? "unanswered" : (answer.option_id == payload.fetch("correct_option_id") ? "correct" : "incorrect")
              selected_choice = answer && payload.fetch("options").find { |option| option["id"] == answer.option_id }
              selected = selected_choice && option_label(payload, selected_choice)
              questions[index].slice(:position,:topic,:level,:clef,:correct_label).merge(
                outcome: outcome, selected_label: selected, elapsed_ms: answer&.response_elapsed_ms)
            end
            elapsed = details.filter_map { |question| question[:elapsed_ms] }
            { nickname: member.nickname, avatar_id: member.avatar_id, status: member.status,
              **score.slice(:place,:points,:correct,:total),
              incorrect: details.count { |question| question[:outcome] == "incorrect" },
              technical: details.count { |question| question[:outcome] == "technical" },
              unanswered: details.count { |question| question[:outcome] == "unanswered" },
              mean_elapsed_ms: elapsed.any? ? elapsed.sum / elapsed.size.to_f : nil,
              questions: details,
              topics: details.group_by { |question| question.values_at(:topic,:level,:clef) }.map do |(topic,level,clef),items|
                { topic: topic, level: level, clef: clef, correct: items.count { |item| item[:outcome] == "correct" },
                  incorrect: items.count { |item| item[:outcome] == "incorrect" }, unanswered: items.count { |item| item[:outcome] == "unanswered" }, total: items.count { |item| item[:outcome] != "technical" } }
              end }
          end.sort_by { |player| [player[:place] || Float::INFINITY,player[:nickname]] }
          { title: room.title, state: room.state, ended_at: room.ended_at, scoring_version: room.scoring_version,
            valid_count: rounds.size, void_count: room.arena_rounds.where(state: "void").count,
            players: players, questions: questions }
        end
      end
    end

    def self.option_label(payload, choice)
      return choice.fetch("label") unless payload.dig("entry","kind") == "melodic_dictation"
      original = payload.dig("entry","exercise","options").find { |option| option["id"] == choice["source_option_id"] }
      durations = { 1 => "semicolcheia", 2 => "colcheia", 3 => "colcheia pontuada", 4 => "semínima", 6 => "semínima pontuada", 8 => "mínima", 12 => "mínima pontuada", 16 => "semibreve" }
      original.fetch("voices").each_with_index.map do |voice,index|
        notes = voice.fetch("events").map do |event|
          note = MusicTheory::Note.parse(event.fetch("pitch"))
          name = %w[Dó Ré Mi Fá Sol Lá Si].fetch(MusicTheory::Note::STEPS.index(note.step))
          "#{name}#{MusicTheory::Note::SYMBOLS.fetch(note.alter)}#{note.octave} (#{durations.fetch(event.fetch('duration_steps'))})"
        end
        "Voz #{index + 1}: #{notes.join(', ')}"
      end.join("; ")
    end

    def self.csv(report)
      CSV.generate(col_sep: ";", encoding: "UTF-8") do |csv|
        csv << ["Apelido", "Participação", "Questão", "Conteúdo", "Nível", "Clave", "Resultado", "Resposta enviada", "Resposta correta", "Tempo ativo (s)", "Pontos na partida"]
        report[:players].each do |player|
          player[:questions].each do |question|
            csv << [player[:nickname], player[:status] == "left" ? "Saiu" : (player[:status] == "removed" ? "Removido" : "Participou"),
              question[:position], question[:topic], question[:level], question[:clef], OUTCOMES.fetch(question[:outcome]),
              question[:selected_label] || "Sem resposta", question[:correct_label],
              question[:elapsed_ms] ? question[:elapsed_ms] / 1000.0 : "Indisponível", player[:points]].map { |value| csv_cell(value) }
          end
        end
      end
    end

    def self.csv_cell(value)
      value.is_a?(String) && value.match?(/\A(?:\s*[=+\-@]|[\t\r\n])/) ? "'#{value}" : value
    end
    private_class_method :csv_cell
  end
end
