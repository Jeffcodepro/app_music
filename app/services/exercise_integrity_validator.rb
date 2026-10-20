require "digest"

# Canonical parsing and independent arithmetic for the existing curriculum only.
# No generator/HeadMusic or canonical interval classification is trusted as an
# answer. MIDI/diatonic relations below are recalculated from the written fields.
class ExerciseIntegrityValidator
  class Invalid < ArgumentError; end
  LETTERS = %w[C D E F G A B].freeze
  NATURAL = [0, 2, 4, 5, 7, 9, 11].freeze
  BASES = { "treble" => ["E", 4], "bass" => ["G", 2], "alto" => ["F", 3] }.freeze
  INTERVAL_NAMES = %w[unison second third fourth fifth sixth seventh octave ninth tenth eleventh twelfth thirteenth fourteenth fifteenth].freeze
  QUALITIES = {
    [0, 4, 7] => "major_triad", [0, 3, 7] => "minor_triad", [0, 3, 6] => "diminished_triad",
    [0, 4, 7, 11] => "major_major_seventh_chord", [0, 4, 7, 10] => "major_minor_seventh_chord",
    [0, 3, 7, 10] => "minor_minor_seventh_chord", [0, 3, 6, 10] => "half_diminished_seventh_chord"
  }.freeze
  KEYS = %w[c_major g_major d_major a_major e_major b_major fs_major cs_major f_major bb_major eb_major ab_major db_major gb_major cb_major].freeze
  SHARP_POSITIONS = { "treble" => [8, 5, 9, 6, 3, 7, 4], "bass" => [6, 3, 7, 4, 1, 5, 2], "alto" => [7, 4, 8, 5, 2, 6, 3] }.freeze
  FLAT_POSITIONS = { "treble" => [4, 7, 3, 6, 2, 5, 1], "bass" => [2, 5, 1, 4, 0, 3, -1], "alto" => [3, 6, 2, 5, 1, 4, 0] }.freeze

  def self.validate!(area, exercise)
    new(area, exercise).validate!
  end

  def self.digest(area, exercise)
    # Hash a canonical ordering; JSONB does not retain Ruby hash insertion order.
    sort = ->(value) do
      case value
      when Hash then value.stringify_keys.except("assignment_id", "attempt_token").sort.to_h.transform_values { |v| sort.call(v) }
      when Array then value.map { |v| sort.call(v) }
      else value
      end
    end
    Digest::SHA256.hexdigest(JSON.generate([area, sort.call(exercise)]))
  end

  def initialize(area, exercise)
    @area = area
    @e = exercise.to_h.deep_symbolize_keys
  end

  def validate!
    if @area == "ritmica" && @e.key?(:rhythm_format)
      return MetricalRhythmIntegrityValidator.validate!(@e)
    end
    if @area == "percepcao" && @e[:question_type] == "melodic_dictation"
      return VoicedDictationIntegrityValidator.validate!(@e) if @e.key?(:dictation_format)
      return MelodicDictationIntegrityValidator.validate!(@e)
    end
    options = @e.fetch(:options)
    check(options.is_a?(Array) && options.size == 4, "options")
    ids = options.map { |option| option.fetch(:id) }
    check(ids.all? { |id| id.is_a?(String) && id.present? } && ids.uniq.size == 4, "option_ids")
    expected = case @area
               when "leitura" then reading_answer
               when "percepcao" then perception_answer
               when "harmonia" then harmony_answer
               when "ritmica" then rhythm_answer
               else raise Invalid, "area"
               end
    check(@e.fetch(:correct_option_id) == expected && ids.count(expected) == 1, "answer")
    options.each do |option|
      expected_label = option_label(option.fetch(:id))
      check(expected_label.present? && (option[:label] || option[:aria_label]) == expected_label, "option_label")
    end
    check(@e.fetch(:correct_option_label) == option_label(expected), "answer_label")
    true
  rescue KeyError, TypeError, NoMethodError, IndexError, ArgumentError => error
    raise error if error.is_a?(Invalid)
    raise Invalid, "malformed_payload"
  end

  private

  def option_label(id)
    case @area
    when "leitura"
      case @e[:question_type]
      when "note_name" then ReadingNoteExerciseGenerator.note_option(id)&.dig(:label)
      when "accidental" then ReadingNoteExerciseGenerator.accidental_note_option(id)&.dig(:label)
      when "key_signature" then ReadingNoteExerciseGenerator.key_signature_definition(id)&.dig(:label)
      end
    when "percepcao"
      PerceptionIntervalExerciseGenerator::INTERVAL_LIBRARY.find { |entry| entry[:id] == id }&.dig(:label)
    when "harmonia"
      case @e[:question_type]
      when "quality" then HarmonyExerciseGenerator.quality_definition(@e[:chord_structure], id)&.dig(:label)
      when "harmonic_function" then HarmonyExerciseGenerator.function_definition(id)&.dig(:label)
      else
        return unless id.match?(/\A[1-7]\z/)
        romans = @e[:chord_structure] == "triad" ? HarmonyExerciseGenerator::TRIAD_ROMAN_NUMERALS : HarmonyExerciseGenerator::TETRAD_ROMAN_NUMERALS
        "#{romans.fetch(id.to_i)} (#{id}º grau)"
      end
    when "ritmica"
      RhythmExerciseGenerator.option_from_signature(id)&.dig(:aria_label)
    end
  end

  def check(condition, rule)
    raise Invalid, rule unless condition
  end

  def pitch(value)
    note = MusicTheory::Note.parse(value)
    letter = LETTERS.index(note.step)
    octave = note.octave
    alteration = note.alter
    { midi: 12 * (octave + 1) + NATURAL[letter] + alteration, diatonic: octave * 7 + letter, alteration: }
  end

  def check_frequency(name, frequency)
    check(frequency.is_a?(Numeric) && frequency.finite? && frequency.positive?, "frequency")
    check((frequency - 440.0 * 2**((pitch(name)[:midi] - 69) / 12.0)).abs <= 0.001, "pitch_frequency")
  end

  def reading_answer
    clef = @e.fetch(:clef_id)
    check(@e.fetch(:head_music_clef) == { "treble" => "treble_clef", "bass" => "bass_clef", "alto" => "alto_clef" }.fetch(clef), "clef_identity")
    base_letter, base_octave = BASES.fetch(clef)
    case @e.fetch(:question_type)
    when "note_name", "accidental"
      check(@e.fetch(:notation_kind) == "note", "note_notation")
      position = @e.fetch(:staff_position_index)
      check(position.is_a?(Integer) && (-6..14).cover?(position), "staff_position")
      expected = base_octave * 7 + LETTERS.index(base_letter) + position
      actual = pitch(@e.fetch(:pitch_name))
      check(actual[:diatonic] == expected && actual[:alteration].zero?, "staff_pitch")
      letter = LETTERS[expected % 7].downcase
      if @e[:question_type] == "accidental"
        accidental = @e.fetch(:note_accidental_id)
        definition = ExercisePresentation::ACCIDENTALS.fetch(accidental)
        check(@e.fetch(:note_accidental_symbol) == definition[:symbol], "accidental_symbol")
        check(@e.fetch(:note_accidental_label) == definition[:label], "accidental_label")
        "#{letter}__#{accidental}"
      else
        check(@e[:note_accidental_id].blank? && @e[:note_accidental_symbol].blank?, "unexpected_accidental")
        letter
      end
    when "key_signature"
      check(@e.fetch(:notation_kind) == "key_signature", "key_notation")
      key = @e.fetch(:key_signature_id)
      index = KEYS.index(key)
      check(index, "key_signature")
      sharp = index.between?(1, 7)
      count = index.zero? ? 0 : (sharp ? index : index - 7)
      expected = (sharp ? SHARP_POSITIONS : FLAT_POSITIONS).fetch(clef).first(count)
      symbols = @e.fetch(:key_signature_accidentals)
      check(symbols.map { |entry| entry[:staff_position_index] } == expected, "key_positions")
      check(symbols.all? { |entry| entry[:accidental_id] == (sharp ? "sharp" : "flat") && entry[:symbol] == (sharp ? "♯" : "♭") }, "key_symbols")
      key
    else raise Invalid, "reading_type"
    end
  end

  def perception_answer
    validate_listening_difficulty("perception-levels-v1")
    first = pitch(@e.fetch(:reference_pitch))
    last = pitch(@e.fetch(:target_pitch))
    check_instrument_register([first, last]) if @e.key?(:register_version)
    distance = (last[:diatonic] - first[:diatonic]).abs
    semitones = (last[:midi] - first[:midi]).abs
    check((1..14).cover?(distance), "interval_range")
    major_semitones = NATURAL[distance % 7] + 12 * (distance / 7)
    perfect = [0, 3, 4].include?(distance % 7)
    quality = if semitones == major_semitones
                perfect ? "perfect" : "major"
              elsif !perfect && semitones == major_semitones - 1
                "minor"
              else raise Invalid, "interval_quality"
              end
    direction = last[:midi] > first[:midi] ? "ascending" : "descending"
    check(@e.fetch(:direction) == direction, "interval_direction")
    check((last[:diatonic] <=> first[:diatonic]) == (last[:midi] <=> first[:midi]), "interval_spelling_direction")
    mode = @e.fetch(:direction_mode)
    check(ExercisePresentation::DIRECTION_MODES.key?(mode) && (mode == "mixed" || mode == direction), "interval_direction_mode")
    check(@e.fetch(:direction_mode_label) == ExercisePresentation::DIRECTION_MODES.fetch(mode), "interval_mode_label")
    check(@e.fetch(:direction_label) == ExercisePresentation::DIRECTIONS.fetch(direction), "interval_direction_label")
    check(@e.fetch(:question) == ExercisePresentation::INTERVAL_QUESTION, "interval_question")
    check_frequency(@e.fetch(:reference_pitch), @e.fetch(:reference_frequency))
    check_frequency(@e.fetch(:target_pitch), @e.fetch(:target_frequency))
    "#{quality}_#{INTERVAL_NAMES.fetch(distance)}"
  end

  def chord(key, degree)
    check(degree.is_a?(Integer) && (1..7).cover?(degree), "degree")
    root = pitch(key.fetch(:root_pitch))
    size = @e.fetch(:chord_structure) == "triad" ? 3 : 4
    (0...size).map do |index|
      offset = degree - 1 + index * 2
      { midi: root[:midi] + NATURAL[offset % 7] + 12 * (offset / 7), diatonic: root[:diatonic] + offset }
    end
  end

  def check_audio_chord(actual, expected)
    if @e[:difficulty_version] == "harmony-levels-v1"
      inversion = actual.fetch(:inversion)
      check(inversion.is_a?(Integer) && (@e[:level] == 4 ? (1...expected.size).cover?(inversion) : inversion.zero?), "chord_inversion")
      expected = expected.drop(inversion) + expected.take(inversion).map { |n| { midi: n[:midi] + 12, diatonic: n[:diatonic] + 7 } }
    end
    if @e.key?(:register_version)
      offset = actual.fetch(:register_offset)
      check(offset.is_a?(Integer) && [-24,-12,0,12,24].include?(offset), "harmony_register_offset")
      expected = expected.map { |n| { midi: n[:midi] + offset, diatonic: n[:diatonic] + offset / 12 * 7 } }
      check_instrument_register(expected)
    end
    names = actual.fetch(:pitches)
    frequencies = actual.fetch(:frequencies)
    check(names.size == expected.size && frequencies.size == expected.size, "chord_size")
    names.zip(expected, frequencies).each do |name, target, frequency|
      parsed = pitch(name)
      check(parsed.slice(:midi, :diatonic) == target, "chord_pitch")
      check_frequency(name, frequency)
    end
  end

  def check_instrument_register(notes)
    check(@e[:register_version] == "concert-register-v1", "instrument_register_version")
    register = ExerciseInstrumentRegister.range(@e.fetch(:instrument))
    check(notes.all? { |note| register.cover?(note[:midi]) }, "instrument_register")
  end

  def harmony_answer
    validate_listening_difficulty("harmony-levels-v1")
    structure = @e.fetch(:chord_structure)
    check(%w[triad tetrad].include?(structure), "chord_structure")
    # These are the existing approved input catalog and editorial convention,
    # not an independent claim about universal harmonic function.
    key = HarmonyExerciseGenerator.key_definition(@e.fetch(:key_id))
    check(key, "key")
    degree = @e.fetch(:chord_degree)
    target = chord(key, degree)
    type = @e.fetch(:question_type)
    if type == "progression"
      template = HarmonyExerciseGenerator.progression_template(@e.fetch(:progression_template_id))
      check(template, "progression")
      focus = @e.fetch(:progression_focus_index)
      check(focus.is_a?(Integer) && (1..template[:sequence].size).cover?(focus), "focus")
      check(degree == template[:sequence].fetch(focus - 1), "progression_degree")
      check(@e.fetch(:question) == ExercisePresentation.progression_question(focus), "progression_question")
      check(@e.fetch(:prompt_label) == "Ponto de escuta" && @e.fetch(:prompt_value) == ExercisePresentation.progression_prompt(focus), "progression_prompt")
      check(@e.fetch(:progression_steps) == ExercisePresentation.progression_steps(template[:sequence].size, focus), "progression_visual_focus")
      check(@e.fetch(:context_items).select { |item| item[:label] == "Alvo" } == [{ label: "Alvo", value: ExercisePresentation.ordinal(focus) }], "progression_context")
      expected_audio = template[:sequence].map { |entry| chord(key, entry) }
    else
      check(%w[quality scale_degree harmonic_function].include?(type), "harmony_type")
      expected_audio = %w[scale_degree harmonic_function].include?(type) ? [chord(key, 1), target] : [target]
    end
    audio = @e.fetch(:audio_sequence)
    check(audio.size == expected_audio.size, "chord_sequence")
    audio.zip(expected_audio).each { |actual, expected| check_audio_chord(actual, expected) }
    shape = target.map { |note| note[:midi] - target.first[:midi] }
    quality = QUALITIES.fetch(shape)
    check(@e.fetch(:chord_quality_id) == quality, "chord_quality")
    case type
    when "quality" then quality
    when "harmonic_function"
      # The degree has already been proved from the actual tonal pitches above.
      # Classification is explicitly scoped to a versioned editorial convention.
      function = HarmonicFunctionConvention.function(degree, version: @e.fetch(:function_convention_id))
      check(@e.fetch(:question) == HarmonyExerciseGenerator.question_prompt(type, structure), "function_instruction")
      check(@e.fetch(:chord_function_id) == function, "function_metadata")
      check(@e.fetch(:chord_function_label) == option_label(function), "function_label")
      function
    else degree.to_s
    end
  end

  def validate_listening_difficulty(version)
    return unless @e.key?(:level) || @e.key?(:difficulty_version)
    level = @e[:level]
    check(level.is_a?(Integer) && (1..4).cover?(level) && @e[:difficulty_version] == version, "difficulty_profile")
    if version == "perception-levels-v1"
      check(@e[:options].all? { |o| ListeningDifficulty.intervals(level).include?(o[:id]) }, "interval_difficulty")
    else
      allowed = ListeningDifficulty.harmony_modes(level)
      check(allowed.include?(@e[:question_type]) && (@e[:question_mode] == "mixed" || @e[:question_mode] == @e[:question_type]), "harmony_difficulty_type")
      check(ListeningDifficulty.harmony_keys(level).include?(@e[:key_id]), "harmony_difficulty_key")
      check(ListeningDifficulty.harmony_structures(level).include?(@e[:chord_structure]), "harmony_difficulty_structure")
      check(ListeningDifficulty.harmony_degrees(level).include?(@e[:chord_degree]), "harmony_difficulty_degree")
      if @e[:question_type] == "scale_degree"
        check(@e[:options].all? { |o| ListeningDifficulty.harmony_degrees(level).map(&:to_s).include?(o[:id]) }, "harmony_difficulty_options")
      end
      check(%w[authentic_cadence ii_v_i].include?(@e[:progression_template_id]), "harmony_difficulty_progression") if level == 3 && @e[:question_type] == "progression"
    end
  end

  def rhythm_answer
    mode = @e.fetch(:activity_mode)
    check(mode != "syncopation", "syncopation_unavailable")
    check(RhythmExerciseGenerator::MODE_CONFIGS.key?(mode), "rhythm_mode")
    config = RhythmExerciseGenerator::MODE_CONFIGS.fetch(mode)
    check(@e.fetch(:tempo_bpm).is_a?(Integer) && config[:tempo_range].cover?(@e[:tempo_bpm]), "tempo")
    check(@e.fetch(:time_signature_label) == "4/4" && @e.fetch(:count_in_beats) == 4, "meter")
    check(@e.fetch(:playback_cycles) == config[:playback_cycles] && @e.fetch(:metronome_during_pattern) == config[:metronome_during_pattern], "rhythm_playback")
    ids = @e.fetch(:options).map { |option| option.fetch(:id) }
    events = ids.to_h { |id| [id, independent_rhythm_events(id)] }
    @e[:options].each { |option| check(option.fetch(:pattern_signature) == option.fetch(:id), "rhythm_notation") }
    projections = ids.map { |id| events.fetch(id).map { |event| event[:start_step] } }
    check(projections.uniq.size == 4, "ambiguous_attacks")
    correct = @e.fetch(:correct_option_id)
    check(ids.include?(correct), "rhythm_answer")
    check(@e.fetch(:audio_events) == events.fetch(correct), "rhythm_audio")
    ids.each { |id| check_rhythm_mode(mode, id, events.fetch(id)) }
    check(@e.fetch(:question) == config[:description] && @e.fetch(:prompt_value) == config[:prompt_value] && @e.fetch(:focus_label) == config[:focus_label], "rhythm_instruction")
    check(@e.fetch(:activity_mode_label) == RhythmExerciseGenerator.activity_mode_definition(mode)[:label], "rhythm_mode_label")
    correct
  end

  # Independent beat grouping; do not reuse the generator's motif predicate.
  def check_rhythm_mode(mode, signature, events)
    check(events.size >= 2, "rhythm_note_count")
    beats = Array.new(4) { [] }
    cursor = 0
    signature.split(".").each do |token|
      duration = token[1].to_i
      check(cursor / 4 == (cursor + duration - 1) / 4, "rhythm_beat_group")
      beats[cursor / 4] << token
      cursor += duration
    end
    valid = case mode
            when "pulse" then beats.all? { |beat| [%w[n4], %w[r4]].include?(beat) } && beats.count(%w[n4]) >= 2
            when "subdivision" then beats.any? { |beat| beat.size >= 2 }
            when "precision" then beats.count { |beat| beat.size >= 3 } >= 2
            else false
            end
    check(valid, "rhythm_mode_semantics")
  end

  def independent_rhythm_events(signature)
    check(signature.is_a?(String) && /\A[nr][124](?:\.[nr][124])*\z/.match?(signature), "rhythm_token")
    cursor = 0
    events = []
    signature.split(".").each do |token|
      duration = Integer(token[1], 10)
      events << { start_step: cursor, duration_steps: duration } if token[0] == "n"
      cursor += duration
    end
    check(cursor == 16, "rhythm_measure")
    events
  end
end
