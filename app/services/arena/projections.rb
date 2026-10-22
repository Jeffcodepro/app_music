module Arena
  class Projections
    def self.question(snapshot)
      projection = { id: snapshot.id, payload_version: snapshot.payload_version, prompt: text(snapshot.payload.fetch("prompt")),
        options: snapshot.payload.fetch("options").map { |option| { id: text(option.fetch("id")), label: text(option.fetch("label")) } } }
      if snapshot.payload_version == MusicContent::TYPE
        raise InvalidContent, "Snapshot digest mismatch" unless Catalog.digest(snapshot.payload) == snapshot.payload_digest
        MusicContent.validate_snapshot!(snapshot.payload, content_version_id: snapshot.arena_content_version_id, verify_renderer: false)
        projection[:stimulus] = snapshot.payload.fetch("stimulus").deep_dup
        projection[:svg] = projection[:stimulus]["svg"]
        projection[:options] = snapshot.payload.fetch("options").map { |o| { id: o.fetch("id"), label: o.fetch("label"), svg: o["svg"] } }
        projection[:topic] = "#{MusicContent::AREAS.fetch(snapshot.payload.dig('entry','area'))} · Nível #{snapshot.payload.dig('entry','level')}"
      end
      if %w[reading-note-v1 reading-visual-v2].include?(snapshot.payload_version)
        raise InvalidContent, "Snapshot digest mismatch" unless Catalog.digest(snapshot.payload) == snapshot.payload_digest
        adapter = snapshot.payload_version == "reading-visual-v2" ? ReadingVisualContent : ReadingContent
        adapter.validate_snapshot!(snapshot.payload, content_version_id: snapshot.arena_content_version_id, verify_renderer: false)
        projection[:svg] = text(snapshot.payload.fetch("svg"))
      end
      projection
    end

    def self.acknowledgement(answer)
      { accepted: true, answer_id: answer.id, round_id: answer.arena_round_id }
    end

    def self.text(value)
      raise PrivatePayload, "Invalid display field" unless value.is_a?(String)
      value.dup
    end
    private_class_method :text
  end
end
