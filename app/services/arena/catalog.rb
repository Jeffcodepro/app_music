module Arena
  class Catalog
    CODE = "treble-natural-l1-local-v1".freeze
    VISUAL_REVISION = 2
    def self.technical_preview? = Rails.env.development? || (Rails.env.test? && ENV["APP_MUSIC_ARENA_PREVIEW"] == "1")

    def self.available
      versions = ArenaContentVersion.where(status: technical_preview? ? %w[published technical_preview] : ["published"])
      latest = versions.select("DISTINCT ON (code) id").reorder(Arel.sql("code, revision DESC"))
      ArenaContentVersion.where(id: latest).order(:title, :revision)
    end

    def self.create_preview!
      raise Forbidden, "Technical fixtures are local only" unless Rails.env.test? || technical_preview?
      SchemaIntegrity.verify!
      source = ReadingContent.source_digest
      existing = ArenaContentVersion.find_by(code: CODE, revision: 1)
      if existing
        raise InvalidContent, "Source changed; create a new content revision" unless existing.source_digest == source
        validate!(existing)
        return existing
      end
      body = ReadingContent.package
      ArenaContentVersion.create!(code: CODE, revision: 1, title: "Notas na clave de Sol · Nível 1", status: "technical_preview",
        body: body, content_digest: digest(body), source_digest: source)
    end

    def self.digest(body)
      canonical = ->(value) {
        case value
        when Hash then value.sort.to_h.transform_values { |nested| canonical.call(nested) }
        when Array then value.map { |nested| canonical.call(nested) }
        else value
        end
      }
      Digest::SHA256.hexdigest(JSON.generate(canonical.call(body)))
    end

    def self.create_visual_previews!
      raise Forbidden, "Technical fixtures are local only" unless Rails.env.test? || technical_preview?
      SchemaIntegrity.verify!
      source = ReadingVisualContent.source_digest
      (1..4).flat_map do |number|
        ReadingVisualContent::PROMPTS.keys.map do |type|
          code = "reading-#{type.tr('_','-')}-l#{number}-visual-v2"
          existing = ArenaContentVersion.find_by(code: code, revision: VISUAL_REVISION)
          if existing
            raise InvalidContent, "Source changed; create a new content revision" unless existing.source_digest == source
            validate!(existing)
            next existing
          end
          body = ReadingVisualContent.package(level: "level_#{number}", question_type: type)
          ReadingVisualContent.validate_package!(body)
          ArenaContentVersion.create!(code: code, revision: VISUAL_REVISION, title: "#{ReadingVisualContent::LABELS.fetch(type)} · Nível #{number}", status: "technical_preview",
            body: body, content_digest: digest(body), source_digest: source)
        end
      end
    end

    def self.validate!(content)
      body = content.body
      if body["type"] == MusicContent::TYPE
        raise InvalidContent, "Content digest mismatch" unless content.content_digest == digest(body)
        return MusicContent.validate_package!(body)
      end
      if body["type"] == ReadingVisualContent::TYPE
        raise InvalidContent, "Content digest mismatch" unless content.content_digest == digest(body)
        return ReadingVisualContent.validate_package!(body)
      end
      unless content.content_digest == digest(body) && body.keys.sort == %w[exercises type] && body["type"] == "treble-natural-l1-v1" && body["exercises"].size == 9
        raise InvalidContent, "Content digest or contract mismatch"
      end
      body.fetch("exercises").each { |exercise| ReadingContent.validate!(exercise) }
      unless body.fetch("exercises").map { |exercise| exercise.fetch("staff_position_index") }.sort == (0..8).to_a
        raise InvalidContent, "Incomplete reference set"
      end
      true
    end

    # Trusted editorial console only. A teacher grant is not editorial authority.
    def self.publish!(content:, reviewer_reference:)
      raise ArgumentError, "Review operation UUID required" unless HostAccess::UUID.match?(reviewer_reference.to_s)
      content.with_lock do
        raise InvalidContent, "Archived content cannot be published" if content.status == "archived"
        validate!(content)
        content.update!(status: "published", reviewer_reference: reviewer_reference, reviewed_at: Time.current) unless content.published?
      end
      content
    end
  end
end
