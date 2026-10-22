module Arena
  class ReadingVisualContent
    TYPE = "reading-visual-v2".freeze
    CLEFS = %w[treble bass alto].freeze
    PROMPTS = { "note_name" => "Qual é a nota na pauta?", "accidental" => "Qual nota e acidente estão escritos?", "key_signature" => "Qual é a tonalidade maior da armadura?" }.freeze
    LABELS = { "note_name" => "Notas", "accidental" => "Acidentes", "key_signature" => "Armaduras" }.freeze
    SOURCES = %w[app/services/arena/reading_visual_content.rb app/services/arena/notation_renderer.rb app/services/reading_note_exercise_generator.rb app/services/exercise_integrity_validator.rb app/services/exercise_presentation.rb app/services/melodic_dictation_svg_renderer.rb app/services/voiced_dictation_svg_renderer.rb].freeze

    def self.source_digest = Digest::SHA256.hexdigest(SOURCES.map { |path| File.binread(Rails.root.join(path)) }.join)

    def self.profile!(profile)
      level = ReadingNoteExerciseGenerator.season_definition(profile["level"])
      unless profile.keys.sort == %w[clefs level question_type] && level && profile["clefs"] == CLEFS && PROMPTS.key?(profile["question_type"])
        raise InvalidContent, "Unsupported reading profile"
      end
      level
    end

    def self.validate!(exercise, profile:)
      level = profile!(profile)
      ExerciseIntegrityValidator.validate!("leitura", exercise)
      type = profile.fetch("question_type")
      clef = ReadingNoteExerciseGenerator.clef_definition(exercise["clef_id"])
      valid = exercise.values_at("season_id","season_mode","season_label","question_type","question_mode") ==
        [profile["level"],profile["level"],level[:label],type,type] &&
        CLEFS.include?(exercise["clef_id"]) && exercise["clef_mode"] == exercise["clef_id"] && clef &&
        exercise.values_at("clef_label","head_music_clef") == clef.values_at(:label,:head_music)
      incompatible = case type
      when "note_name" then exercise.keys.any? { |key| key.start_with?("key_signature", "note_accidental") }
      when "accidental" then exercise.keys.any? { |key| key.start_with?("key_signature") }
      else exercise.keys.any? { |key| key.start_with?("note_accidental") || %w[staff_position_index pitch_name pitch_label].include?(key) }
      end
      valid &&= !incompatible
      valid &&= if type == "key_signature"
        level.fetch(:key_signature_ids).include?(exercise["key_signature_id"])
      else
        exercise["staff_position_index"].is_a?(Integer) && level.fetch(:staff_position_range).cover?(exercise["staff_position_index"]) &&
          (type != "accidental" || level.fetch(:accidental_ids).include?(exercise["note_accidental_id"]))
      end
      if type == "accidental"
        valid &&= exercise.fetch("options").all? do |option|
          definition = ReadingNoteExerciseGenerator.accidental_note_option(option["id"])
          definition && level.fetch(:accidental_ids).include?(definition[:accidental_id])
        end
      end
      raise InvalidContent, "Exercise differs from its level or topic" unless valid
      true
    rescue ExerciseIntegrityValidator::Invalid, KeyError, TypeError, NoMethodError => error
      raise InvalidContent, "Invalid visual reading content (#{error.class})"
    end

    def self.package(level:, question_type:)
      profile = { "level" => level, "question_type" => question_type, "clefs" => CLEFS.dup }
      definition = profile!(profile)
      @packages ||= {}
      @packages[[level,question_type]] ||= begin
        exercises = CLEFS.flat_map do |clef|
          target = case question_type
          when "note_name" then definition.fetch(:staff_position_range).size
          when "key_signature" then definition.fetch(:key_signature_ids).size
          else 18
          end
          found = {}
          2500.times do |seed|
            value = ReadingNoteExerciseGenerator.new(clef_mode: clef, question_mode: question_type, season_mode: level, random: Random.new(seed)).call.deep_stringify_keys
            validate!(value, profile: profile)
            identity = stimulus_identity(value)
            found[identity] ||= value
            break if found.size == target
          end
          raise InvalidContent, "Incomplete reading package" unless found.size == target
          found.values
        end
        { "type" => TYPE, "profile" => profile, "exercises" => exercises }
      end
      @packages.fetch([level,question_type]).deep_dup
    end

    def self.validate_package!(body)
      raise InvalidContent, "Invalid package fields" unless body.keys.sort == %w[exercises profile type] && body["type"] == TYPE
      profile!(body.fetch("profile"))
      exercises = body.fetch("exercises")
      raise InvalidContent, "Insufficient or excessive content" unless exercises.is_a?(Array) && exercises.size.between?(9,100)
      exercises.each { |exercise| validate!(exercise, profile: body.fetch("profile")) }
      identities = exercises.map { |exercise| stimulus_identity(exercise) }
      raise InvalidContent, "Repeated musical stimulus" unless identities.uniq.size == exercises.size
      raise InvalidContent, "Incomplete clef coverage" unless exercises.map { |exercise| exercise["clef_id"] }.uniq.sort == CLEFS.sort
      true
    rescue KeyError, TypeError, NoMethodError => error
      raise InvalidContent, "Invalid visual package (#{error.class})"
    end

    def self.snapshot(exercise, content_version:, random: Random.new)
      profile = content_version.body.fetch("profile")
      validate!(exercise, profile: profile)
      options = exercise.fetch("options").shuffle(random: random).map { |option| { "id" => SecureRandom.hex(8), "label" => option.fetch("label") } }
      { "prompt" => PROMPTS.fetch(profile.fetch("question_type")), "options" => options,
        "correct_option_id" => options.find { |option| option["label"] == exercise.fetch("correct_option_label") }.fetch("id"),
        "exercise" => exercise.deep_dup, "profile" => profile.deep_dup, "content_version_id" => content_version.id,
        "source_status" => content_version.status, "svg" => NotationRenderer.new(exercise: exercise).call }
    end

    def self.validate_snapshot!(payload, content_version_id:, verify_renderer: true)
      raise InvalidContent, "Invalid snapshot fields" unless payload.keys.sort == %w[content_version_id correct_option_id exercise options profile prompt source_status svg]
      validate!(payload.fetch("exercise"), profile: payload.fetch("profile"))
      unless payload["content_version_id"] == content_version_id && %w[published technical_preview].include?(payload["source_status"]) &&
        payload["prompt"] == PROMPTS.fetch(payload.fetch("profile").fetch("question_type")) && payload["svg"].is_a?(String) &&
        (!verify_renderer || payload["svg"] == NotationRenderer.new(exercise: payload.fetch("exercise")).call)
        raise InvalidContent, "Invalid visual presentation"
      end
      options = payload.fetch("options")
      valid = options.is_a?(Array) && options.size == 4 && options.all? { |option| option.is_a?(Hash) && option.keys.sort == %w[id label] && option["id"].is_a?(String) && option["id"].match?(/\A[A-Za-z0-9_-]{1,80}\z/) && option["label"].is_a?(String) && option["label"].strip.length.between?(1,200) }
      raise InvalidContent, "Invalid choices" unless valid && options.map { |option| option["id"] }.uniq.size == 4 && options.map { |option| option["label"] }.uniq.size == 4
      original = payload.fetch("exercise").fetch("options").map { |option| option.fetch("label") }
      correct = options.find { |option| option["id"] == payload["correct_option_id"] }
      unless options.map { |option| option["label"] }.sort == original.sort && correct && correct["label"] == payload.fetch("exercise").fetch("correct_option_label")
        raise InvalidContent, "Invalid answer key"
      end
      true
    rescue KeyError, TypeError, NoMethodError => error
      raise InvalidContent, "Invalid visual snapshot (#{error.class})"
    end

    def self.stimulus_identity(exercise)
      fields = exercise["question_type"] == "key_signature" ? %w[clef_id key_signature_id] : %w[clef_id staff_position_index note_accidental_id]
      exercise.values_at(*fields)
    end
    private_class_method :stimulus_identity
  end
end
