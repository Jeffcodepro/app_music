module Arena
  class ReadingContent
    REFERENCES = %w[E4 F4 G4 A4 B4 C5 D5 E5 F5].freeze
    LETTER_LABELS = { "c" => "Dó", "d" => "Ré", "e" => "Mi", "f" => "Fá", "g" => "Sol", "a" => "Lá", "b" => "Si" }.freeze
    SOURCES = %w[app/services/reading_note_exercise_generator.rb app/services/exercise_integrity_validator.rb app/services/reading_staff_svg_renderer.rb].freeze

    def self.source_digest
      Digest::SHA256.hexdigest(SOURCES.map { |path| File.binread(Rails.root.join(path)) }.join)
    end

    def self.validate!(value)
      exercise = value.to_h.deep_stringify_keys
      ExerciseIntegrityValidator.validate!("leitura", exercise)
      index = exercise.fetch("staff_position_index")
      raise InvalidContent, "Unexpected accidental or key signature" if exercise.keys.any? { |key| key.start_with?("note_accidental", "key_signature") }
      valid = index.is_a?(Integer) && (0..8).cover?(index) && exercise["pitch_name"] == REFERENCES[index] &&
        exercise.values_at("clef_id", "clef_mode", "question_type", "question_mode", "season_id", "notation_kind") ==
          %w[treble treble note_name note_name level_1 note] &&
        exercise["correct_option_id"] == REFERENCES[index][0].downcase &&
        exercise.fetch("options").size == 4 && exercise.fetch("options").all? { |option| LETTER_LABELS[option["id"]] == option["label"] }
      raise InvalidContent, "Outside the reviewed reading subset" unless valid
      true
    rescue ExerciseIntegrityValidator::Invalid, KeyError, TypeError, NoMethodError => error
      raise InvalidContent, "Invalid reading content (#{error.class})"
    end

    def self.package
      found = {}
      1000.times do |seed|
        exercise = ReadingNoteExerciseGenerator.new(clef_mode: "treble", question_mode: "note_name", season_mode: "level_1", random: Random.new(seed)).call.deep_stringify_keys
        validate!(exercise)
        found[exercise.fetch("staff_position_index")] ||= exercise
        break if found.size == 9
      end
      raise InvalidContent, "Incomplete reference package" unless found.size == 9
      { "type" => "treble-natural-l1-v1", "exercises" => found.sort.map(&:last) }
    end

    def self.snapshot(exercise, content_version:, random: Random.new)
      validate!(exercise)
      options = exercise.fetch("options").shuffle(random: random).map { |option| { "id" => SecureRandom.hex(8), "label" => option.fetch("label") } }
      correct = options.find { |option| option.fetch("label") == exercise.fetch("correct_option_label") }.fetch("id")
      { "prompt" => "Qual é a nota na pauta?", "options" => options, "correct_option_id" => correct,
        "exercise" => exercise.deep_dup, "content_version_id" => content_version.id, "source_status" => content_version.status,
        "svg" => render(exercise) }
    end

    def self.render(exercise)
      ReadingStaffSvgRenderer.new(exercise: { clef_id: "treble", clef_label: "Clave de Sol", head_music_clef: "treble_clef", notation_kind: "note", staff_position_index: exercise.fetch("staff_position_index") }).call
    end

    def self.validate_snapshot!(payload, content_version_id:, verify_renderer: true)
      raise InvalidContent, "Unexpected snapshot fields" unless payload.keys.sort == %w[content_version_id correct_option_id exercise options prompt source_status svg]
      raise InvalidContent, "Invalid editorial origin" unless %w[published technical_preview].include?(payload["source_status"])
      validate!(payload.fetch("exercise"))
      valid_svg = payload["svg"].is_a?(String) && (!verify_renderer || payload["svg"] == render(payload.fetch("exercise")))
      raise InvalidContent, "Invalid presentation or source" unless valid_svg && payload["content_version_id"] == content_version_id && payload["prompt"] == "Qual é a nota na pauta?"
      options = payload.fetch("options")
      unless options.is_a?(Array) && options.all? { |option| option.is_a?(Hash) && option.keys.sort == %w[id label] && option["id"].is_a?(String) && option["id"].match?(/\A[A-Za-z0-9_-]{1,80}\z/) } && options.map { |option| option["id"] }.uniq.size == 4
        raise InvalidContent, "Invalid option identity"
      end
      labels = options.map { |option| option.fetch("label") }
      original_labels = payload.fetch("exercise").fetch("options").map { |option| option.fetch("label") }
      correct = options.find { |option| option["id"] == payload["correct_option_id"] }
      unless options.size == 4 && labels.uniq.size == 4 && labels.sort == original_labels.sort && correct && correct["label"] == payload.fetch("exercise").fetch("correct_option_label")
        raise InvalidContent, "Invalid answer alternatives"
      end
      true
    rescue KeyError, TypeError, NoMethodError => error
      raise InvalidContent, "Invalid musical snapshot (#{error.class})"
    end
  end
end
