module Arena
  # v3 freezes existing, independently validated generators. No new curriculum.
  class MusicContent
    TYPE = "music-choice-v3".freeze
    AREAS = { "leitura" => "Leitura", "percepcao" => "Percepção", "ritmica" => "Rítmica", "harmonia" => "Harmonia", "all" => "Todas as áreas" }.freeze
    KINDS = { "note_name" => "Notas", "accidental" => "Acidentes", "key_signature" => "Armaduras", "interval" => "Intervalos", "melodic_dictation" => "Ditados melódicos", "pulse" => "Pulso", "subdivision" => "Subdivisão", "precision" => "Precisão", "quality" => "Qualidade de acordes", "scale_degree" => "Graus", "harmonic_function" => "Função harmônica", "progression" => "Progressões" }.freeze
    SOURCES = %w[app/services/arena/music_content.rb app/services/arena/reading_visual_content.rb app/services/arena/notation_renderer.rb app/services/reading_note_exercise_generator.rb app/services/perception_interval_exercise_generator.rb app/services/voiced_dictation_exercise_generator.rb app/services/harmony_exercise_generator.rb app/services/metrical_rhythm_exercise_generator.rb app/services/exercise_integrity_validator.rb app/services/exercise_presentation.rb app/models/listening_difficulty.rb app/services/voiced_dictation_svg_renderer.rb app/services/rhythm_staff_svg_renderer.rb app/models/music_theory/meter.rb].freeze
    def self.source_digest = Digest::SHA256.hexdigest(SOURCES.map { |p| File.binread(Rails.root.join(p)) }.join)

    def self.kinds(area, level)
      case area
      when "leitura" then ReadingVisualContent::PROMPTS.keys
      when "percepcao" then %w[interval melodic_dictation]
      when "ritmica" then %w[pulse subdivision precision]
      when "harmonia" then ListeningDifficulty.harmony_modes(level)
      else []
      end
    end

    def self.profile!(area:, level:, kind: "mixed")
      area, level, kind = [area, level, kind].map(&:to_s)
      raise InvalidContent, "Área ou nível inválido" unless AREAS.key?(area) && (%w[1 2 3 4 mixed].include?(level))
      levels = level == "mixed" ? (1..4).to_a : [level.to_i]
      raise InvalidContent, "Conteúdo indisponível neste nível" unless kind == "mixed" || (area != "all" && levels.all? { |n| kinds(area,n).include?(kind) })
      { "area" => area, "level" => level, "kind" => kind }
    end

    def self.create_preview!(area:, level:, kind: "mixed")
      raise Forbidden unless Rails.env.test? || Catalog.technical_preview?
      profile = profile!(area: area, level: level, kind: kind)
      source = source_digest
      code = "music-v3-#{Catalog.digest(profile).first(12)}-#{source.first(12)}"
      found = ArenaContentVersion.find_by(code: code, revision: 1)
      if found
        Catalog.validate!(found)
        return found
      end
      body = package(profile)
      validate_package!(body)
      label = "#{AREAS.fetch(profile['area'])} · #{profile['level'] == 'mixed' ? 'Níveis mistos' : "Nível #{profile['level']}"}"
      label += " · #{KINDS.fetch(profile['kind'])}" if profile['kind'] != "mixed"
      ArenaContentVersion.create!(code: code, revision: 1, title: label, status: "technical_preview", body: body, content_digest: Catalog.digest(body), source_digest: source)
    rescue ActiveRecord::RecordNotUnique
      ArenaContentVersion.find_by!(code: code, revision: 1)
    end

    def self.package(profile)
      areas = profile.fetch("area") == "all" ? AREAS.keys - ["all"] : [profile.fetch("area")]
      levels = profile.fetch("level") == "mixed" ? (1..4).to_a : [profile.fetch("level").to_i]
      exercises = areas.flat_map do |area|
        levels.flat_map do |level|
          types = profile.fetch("kind") == "mixed" ? kinds(area,level) : [profile.fetch("kind")]
          types.flat_map do |kind|
            8.times.map do |seed|
              random = Random.new(level * 10000 + seed)
              value = case area
              when "leitura" then ReadingNoteExerciseGenerator.new(clef_mode: ReadingVisualContent::CLEFS[seed % 3], question_mode: kind, season_mode: "level_#{level}", random: random).call
              when "percepcao"
                kind == "interval" ? PerceptionIntervalExerciseGenerator.new(level: level, instrument: "piano", direction_mode: "mixed", random: random).call : VoicedDictationExerciseGenerator.new(level: level, instrument: "piano", random: random).call
              when "ritmica" then MetricalRhythmExerciseGenerator.new(level: level, meter_id: "mixed", activity_mode: kind, random: random).call
              when "harmonia" then HarmonyExerciseGenerator.new(level: level, question_mode: kind, chord_structure: ListeningDifficulty.harmony_structures(level).sample(random: random), instrument: "piano", random: random).call
              end
              { "area" => area, "level" => level, "kind" => kind, "exercise" => value.deep_stringify_keys }
            end.uniq { |entry| stimulus_identity(entry) }
          end
        end
      end
      { "type" => TYPE, "profile" => profile, "exercises" => exercises }
    end

    def self.validate_entry!(entry)
      raise InvalidContent unless entry.keys.sort == %w[area exercise kind level] && (1..4).cover?(entry["level"]) && kinds(entry["area"],entry["level"]).include?(entry["kind"])
      e, area, n, kind = entry.values_at("exercise","area","level","kind")
      ExerciseIntegrityValidator.validate!(area, e)
      if area == "leitura"
        ReadingVisualContent.validate!(e, profile: { "level" => "level_#{n}", "question_type" => kind, "clefs" => ReadingVisualContent::CLEFS })
      else
        raise InvalidContent unless e["level"] == n && (area != "ritmica" || e["activity_mode"] == kind) && (area != "harmonia" || e["question_type"] == kind)
        raise InvalidContent unless e.fetch("instrument", "piano") == "piano"
        raise InvalidContent if kind == "interval" && !ListeningDifficulty.intervals(n).include?(e["correct_option_id"])
        raise InvalidContent if kind == "melodic_dictation" && e["dictation_format"] != "voices-v2"
      end
      true
    rescue ExerciseIntegrityValidator::Invalid, KeyError, TypeError, NoMethodError, ArgumentError => error
      raise InvalidContent, "Invalid musical entry (#{error.class})"
    end

    def self.validate_package!(body)
      raise InvalidContent unless body.keys.sort == %w[exercises profile type] && body["type"] == TYPE
      profile = profile!(**body.fetch("profile").symbolize_keys)
      entries = body.fetch("exercises")
      raise InvalidContent unless entries.is_a?(Array) && entries.size.between?(1,1000)
      entries.each do |entry|
        validate_entry!(entry)
        raise InvalidContent unless (profile["area"] == "all" || entry["area"] == profile["area"]) && (profile["level"] == "mixed" || entry["level"] == profile["level"].to_i) && (profile["kind"] == "mixed" || entry["kind"] == profile["kind"])
      end
      true
    end

    # Hierarchical sampling avoids letting larger pools dominate mixed sessions.
    def self.sample(entries, count, random:)
      available = entries.group_by { |e| e.values_at("area","level","kind") }
      bags = {}
      previous = nil
      Array.new(count) do
        area = available.keys.map(&:first).uniq.sample(random: random)
        level = available.keys.select { |key| key[0] == area }.map { |key| key[1] }.uniq.sample(random: random)
        key = available.keys.select { |k| k[0] == area && k[1] == level }.sample(random: random)
        bags[key] = available.fetch(key).shuffle(random: random) if bags[key].blank?
        bag = bags.fetch(key)
        bag.rotate! if bag.size > 1 && stimulus_identity(bag.first) == previous
        entry = bag.shift
        previous = stimulus_identity(entry)
        entry
      end
    end

    def self.stimulus_identity(entry)
      e = entry.fetch("exercise")
      Catalog.digest(entry.slice("area","level","kind").merge("stimulus" => if entry["area"] == "leitura"
        e.slice("clef_id","staff_position_index","note_accidental_id","key_signature_id")
      else
        e.slice("reference_pitch","target_pitch","audio_events","audio_sequence","tempo_bpm","meter")
      end))
    end

    def self.stimulus(entry)
      e = entry.fetch("exercise")
      case entry.fetch("area")
      when "leitura" then { "kind" => "visual", "svg" => NotationRenderer.new(exercise: e).call }
      when "percepcao"
        if entry["kind"] == "interval"
          { "kind" => "interval", "first_pitch" => e.fetch("reference_pitch"), "second_pitch" => e.fetch("target_pitch"), "first_frequency" => e.fetch("reference_frequency"), "second_frequency" => e.fetch("target_frequency"), "minimum_seconds" => 2.35 }
        else
          { "kind" => "melody", **e.slice("dictation_format","audio_events","voice_count","total_steps","bpm_unit_steps","tempo_bpm"), "minimum_seconds" => 0.45 + e.fetch("total_steps") * 60.0 / e.fetch("tempo_bpm") / e.fetch("bpm_unit_steps") }
        end
      when "harmonia"
        sequence = e.fetch("audio_sequence").map { |chord| chord.slice("pitches","frequencies") }
        { "kind" => "harmony", "sequence" => sequence, "minimum_seconds" => [0.19 + 1.60 * sequence.size, 0.38 + 1.55 * sequence.size].min }
      when "ritmica"
        { "kind" => "rhythm", **e.slice("meter","measure_count","total_steps","audio_events","tempo_bpm","count_in_beats","metronome_during_pattern","playback_cycles"), "minimum_seconds" => 0.17 + MusicTheory::Meter.fetch(e.fetch("meter_id"), level: entry.fetch("level")).measure_steps * (1 + e.fetch("measure_count")) * 60.0 / e.fetch("tempo_bpm") / e.fetch("meter").fetch("bpm_unit_steps") }
      end
    end

    def self.option_svg(entry, option)
      e = entry.fetch("exercise")
      if entry["area"] == "ritmica"
        RhythmStaffSvgRenderer.new(pattern_signature: option.fetch("id"), meter: MusicTheory::Meter.fetch(e.fetch("meter_id"), level: entry.fetch("level")), measure_count: e.fetch("measure_count")).call
      elsif entry["kind"] == "melodic_dictation"
        alternatives = e.fetch("options").map { |o| o.fetch("voices").map(&:deep_symbolize_keys) }
        layout = VoicedDictationSvgRenderer.layout_for(alternatives, total_steps: e.fetch("total_steps"))
        VoicedDictationSvgRenderer.new(voices: option.fetch("voices").map(&:deep_symbolize_keys), total_steps: e.fetch("total_steps"), layout: layout).call
      end
    end

    def self.prompt(entry)
      e = entry.fetch("exercise")
      return ReadingVisualContent::PROMPTS.fetch(entry["kind"]) if entry["area"] == "leitura"
      parts = [e.fetch("question")]
      parts << e["prompt_value"] if e["prompt_value"].present?
      parts << e["prompt"] if e["prompt"].present? && e["prompt"] != e["question"]
      parts << "Tonalidade: #{e['key_label']}." if e["key_label"]
      parts << "#{e['time_signature_label']} · #{e['tempo_bpm']} BPM." if e["tempo_bpm"]
      parts.join(" ")
    end

    def self.snapshot(entry, content_version:, random:)
      validate_entry!(entry)
      options = entry.fetch("exercise").fetch("options").shuffle(random: random).map do |o|
        svg = option_svg(entry,o)
        { "id" => SecureRandom.hex(12), "source_option_id" => o.fetch("id"), "label" => svg ? o.fetch("aria_label", "Partitura musical") : o.fetch("label"), "svg" => svg }
      end
      { "entry" => entry, "content_version_id" => content_version.id, "source_status" => content_version.status,
        "prompt" => prompt(entry), "stimulus" => stimulus(entry), "options" => options,
        "correct_option_id" => options.find { |o| o["source_option_id"] == entry.dig("exercise","correct_option_id") }.fetch("id") }
    end

    def self.validate_snapshot!(payload, content_version_id:, verify_renderer: true)
      raise InvalidContent unless payload.keys.sort == %w[content_version_id correct_option_id entry options prompt source_status stimulus] && payload["content_version_id"] == content_version_id && %w[published technical_preview].include?(payload["source_status"])
      entry = payload.fetch("entry")
      validate_entry!(entry)
      raise InvalidContent unless payload["prompt"] == prompt(entry)
      if entry["area"] == "leitura" && !verify_renderer
        raise InvalidContent unless payload["stimulus"].is_a?(Hash) && payload["stimulus"].keys.sort == %w[kind svg] && payload["stimulus"]["kind"] == "visual" && payload["stimulus"]["svg"].is_a?(String)
      else
        raise InvalidContent unless payload["stimulus"] == stimulus(entry)
      end
      options = payload.fetch("options")
      originals = entry.fetch("exercise").fetch("options")
      raise InvalidContent unless options.size == 4 && options.map { |o| o["id"] }.uniq.size == 4 && options.map { |o| o["source_option_id"] }.sort == originals.map { |o| o["id"] }.sort
      options.each do |o|
        original = originals.find { |value| value["id"] == o["source_option_id"] }
        raise InvalidContent unless o.keys.sort == %w[id label source_option_id svg] && o["id"].match?(/\A[0-9a-f]{24}\z/) && o["label"] == (o["svg"] ? original.fetch("aria_label", "Partitura musical") : original.fetch("label"))
        raise InvalidContent if verify_renderer && o["svg"] != option_svg(entry,original)
      end
      correct = options.find { |o| o["id"] == payload["correct_option_id"] }
      raise InvalidContent unless correct && correct["source_option_id"] == entry.dig("exercise","correct_option_id")
      true
    rescue KeyError, TypeError, NoMethodError, ArgumentError => error
      raise InvalidContent, "Invalid musical snapshot (#{error.class})"
    end
  end
end
