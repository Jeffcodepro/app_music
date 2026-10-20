class HarmonyExerciseGenerator
  QUESTION_MODES = [
    { id: "quality", label: "Qualidade" },
    { id: "scale_degree", label: "Graus" },
    { id: "harmonic_function", label: "Funções" },
    { id: "progression", label: "Progressões" },
    { id: "mixed", label: "Misto" }
  ].freeze

  CHORD_STRUCTURES = [
    { id: "triad", label: "Tríades" },
    { id: "tetrad", label: "Tétrades" }
  ].freeze

  TRIAD_QUALITY_OPTIONS = [
    { id: "major_triad", label: "Tríade maior", short_label: "maior" },
    { id: "minor_triad", label: "Tríade menor", short_label: "menor" },
    { id: "diminished_triad", label: "Tríade diminuta", short_label: "diminuta" },
    { id: "augmented_triad", label: "Tríade aumentada", short_label: "aumentada" }
  ].freeze

  TETRAD_QUALITY_OPTIONS = [
    { id: "major_major_seventh_chord", label: "Tétrade maior com sétima maior", short_label: "com 7M" },
    { id: "major_minor_seventh_chord", label: "Tétrade dominante", short_label: "dominante" },
    { id: "minor_minor_seventh_chord", label: "Tétrade menor com sétima menor", short_label: "menor com 7m" },
    { id: "half_diminished_seventh_chord", label: "Tétrade meio-diminuta", short_label: "meio-diminuta" },
    { id: "diminished_seventh_chord", label: "Tétrade diminuta", short_label: "diminuta" },
    { id: "minor_major_seventh_chord", label: "Tétrade menor com sétima maior", short_label: "menor com 7M" }
  ].freeze

  FUNCTION_OPTIONS = [
    { id: "tonic", label: "Tônica" },
    { id: "subdominant", label: "Subdominante" },
    { id: "dominant", label: "Dominante" },
    { id: "leading_tone", label: "Sensível" }
  ].freeze

  MAJOR_KEYS = [
    { id: "c_major", label: "Dó maior", root_pitch: "C3" },
    { id: "g_major", label: "Sol maior", root_pitch: "G3" },
    { id: "d_major", label: "Ré maior", root_pitch: "D3" },
    { id: "a_major", label: "Lá maior", root_pitch: "A3" },
    { id: "f_major", label: "Fá maior", root_pitch: "F3" },
    { id: "bb_major", label: "Si bemol maior", root_pitch: "Bb3" },
    { id: "eb_major", label: "Mi bemol maior", root_pitch: "Eb3" }
  ].freeze

  # Compatibility for existing callers; the validator does not consult this.
  FUNCTION_BY_DEGREE = HarmonicFunctionConvention::BY_DEGREE

  TRIAD_ROMAN_NUMERALS = {
    1 => "I",
    2 => "ii",
    3 => "iii",
    4 => "IV",
    5 => "V",
    6 => "vi",
    7 => "vii°"
  }.freeze

  TETRAD_ROMAN_NUMERALS = {
    1 => "Imaj7",
    2 => "ii7",
    3 => "iii7",
    4 => "IVmaj7",
    5 => "V7",
    6 => "vi7",
    7 => "viiø7"
  }.freeze

  PROGRESSION_TEMPLATES = [
    {
      id: "authentic_cadence",
      sequence: [1, 4, 5, 1]
    },
    {
      id: "ii_v_i",
      sequence: [2, 5, 1, 6]
    },
    {
      id: "turnaround_to_dominant",
      sequence: [1, 6, 2, 5]
    },
    {
      id: "pop_cycle",
      sequence: [1, 5, 6, 4]
    },
    {
      id: "dominant_arrival",
      sequence: [6, 2, 5, 1]
    }
  ].freeze

  DEFAULT_QUESTION_MODE = "mixed".freeze
  DEFAULT_CHORD_STRUCTURE = "triad".freeze

  def self.question_modes
    QUESTION_MODES
  end

  def self.chord_structures
    CHORD_STRUCTURES
  end

  def self.question_mode_ids
    QUESTION_MODES.map { |mode| mode[:id] }
  end

  def self.chord_structure_ids
    CHORD_STRUCTURES.map { |structure| structure[:id] }
  end

  def self.question_mode_definition(id)
    QUESTION_MODES.find { |mode| mode[:id] == id.to_s }
  end

  def self.chord_structure_definition(id)
    CHORD_STRUCTURES.find { |structure| structure[:id] == id.to_s }
  end

  def self.key_definition(id)
    MAJOR_KEYS.find { |key| key[:id] == id.to_s }
  end

  def self.progression_template(id)
    PROGRESSION_TEMPLATES.find { |template| template[:id] == id.to_s }
  end

  def self.function_definition(id)
    FUNCTION_OPTIONS.find { |option| option[:id] == id.to_s }
  end

  def self.quality_options_for(chord_structure)
    chord_structure.to_s == "tetrad" ? TETRAD_QUALITY_OPTIONS : TRIAD_QUALITY_OPTIONS
  end

  def self.quality_definition(chord_structure, quality_id)
    quality_options_for(chord_structure).find { |option| option[:id] == quality_id.to_s }
  end

  def self.localize_spelling(spelling)
    normalized = spelling.to_s.tr("♯♭", "#b")
    match_data = normalized.match(/\A([A-G])(bb|##|b|#)?\z/)
    return spelling.to_s if match_data.blank?

    note_label = {
      "C" => "Dó",
      "D" => "Ré",
      "E" => "Mi",
      "F" => "Fá",
      "G" => "Sol",
      "A" => "Lá",
      "B" => "Si"
    }.fetch(match_data[1])

    accidental_label = {
      "#" => "sustenido",
      "##" => "duplo sustenido",
      "b" => "bemol",
      "bb" => "duplo bemol"
    }[match_data[2]]

    [note_label, accidental_label].compact.join(" ")
  end

  def self.question_type_label(question_type, chord_structure)
    case question_type.to_s
    when "quality"
      chord_structure.to_s == "tetrad" ? "Tétrades" : "Tríades"
    when "scale_degree"
      "Graus"
    when "harmonic_function"
      "Funções"
    else
      "Progressões"
    end
  end

  def self.question_prompt(question_type, chord_structure)
    case question_type.to_s
    when "quality"
      chord_structure.to_s == "tetrad" ? "Ouça o acorde e identifique a qualidade da tétrade." : "Ouça o acorde e identifique a qualidade da tríade."
    when "scale_degree"
      "Ouça primeiro a tônica da tonalidade e depois o acorde alvo. Identifique em qual grau do campo harmônico maior ele foi formado."
    when "harmonic_function"
      "Ouça primeiro a tônica da tonalidade e depois o acorde alvo. #{HarmonicFunctionConvention::INSTRUCTION}"
    else
      "Ouça a progressão e identifique o grau pedido dentro da sequência."
    end
  end

  def self.ordinal_label(position)
    ExercisePresentation.ordinal(position)
  end

  def self.progression_question(position)
    ExercisePresentation.progression_question(position)
  end

  def initialize(random: Random.new, question_mode: DEFAULT_QUESTION_MODE, chord_structure: DEFAULT_CHORD_STRUCTURE, recent_exercises: [], level: nil, instrument: "piano")
    @instrument = instrument
    ExerciseInstrumentRegister.range(instrument)
    @level = ListeningDifficulty.validate_level!(level) unless level.nil?
    @random = random
    @question_mode = sanitize_question_mode(question_mode)
    @chord_structure = sanitize_chord_structure(chord_structure)
    if @level && ((!ListeningDifficulty.harmony_modes(@level).include?(@question_mode) && @question_mode != "mixed") || !ListeningDifficulty.harmony_structures(@level).include?(@chord_structure))
      raise ArgumentError, "content is unavailable at this difficulty level"
    end
    @recent_exercises = Array(recent_exercises).map { |entry| entry.to_h.symbolize_keys }
  end

  def call
    question_type = sampled_question_type
    key_definition = sampled_key_definition

    exercise = case question_type
               when "quality"
                 build_quality_exercise(key_definition:)
               when "scale_degree"
                 build_scale_degree_exercise(key_definition:)
               when "harmonic_function"
                 build_harmonic_function_exercise(key_definition:)
               else
                 build_progression_exercise(key_definition:)
               end

    exercise = exercise.merge(
      question_mode: @question_mode,
      question_mode_label: self.class.question_mode_definition(@question_mode).fetch(:label),
      chord_structure: @chord_structure,
      chord_structure_label: self.class.chord_structure_definition(@chord_structure).fetch(:label)
    )
    exercise.merge!(level: @level, difficulty_version: "harmony-levels-v1") if @level
    exercise.merge!(instrument: @instrument, register_version: "concert-register-v1") unless @instrument == "piano"
    exercise
  end

  private

  def build_quality_exercise(key_definition:)
    degree = sampled_degree(question_type: "quality", key_definition:)
    chord = chord_for_degree(key_definition:, degree:)
    quality_options = self.class.quality_options_for(@chord_structure)
    distractors = quality_options.reject { |option| option[:id] == chord[:quality_id] }.sample(3, random: @random)
    options = ([self.class.quality_definition(@chord_structure, chord[:quality_id])] + distractors).shuffle(random: @random).map do |option|
      { id: option[:id], label: option[:label] }
    end

    build_common_exercise(
      question_type: "quality",
      key_definition:,
      chord:,
      correct_option_id: chord[:quality_id],
      correct_option_label: chord[:quality_label],
      signature: exercise_signature("quality", key_definition[:id], @chord_structure, degree, chord[:quality_id]),
      options:
    )
  end

  def build_scale_degree_exercise(key_definition:)
    degree = sampled_degree(question_type: "scale_degree", key_definition:)
    chord = chord_for_degree(key_definition:, degree:)
    distractors = (degree_pool - [degree]).sample(3, random: @random)
    options = ([degree] + distractors).shuffle(random: @random).map do |candidate_degree|
      candidate_chord = chord_for_degree(key_definition:, degree: candidate_degree)
      {
        id: candidate_degree.to_s,
        label: "#{candidate_chord[:roman]} (#{candidate_degree}º grau)"
      }
    end

    build_common_exercise(
      question_type: "scale_degree",
      key_definition:,
      chord:,
      correct_option_id: degree.to_s,
      correct_option_label: "#{chord[:roman]} (#{degree}º grau)",
      signature: exercise_signature("scale_degree", key_definition[:id], @chord_structure, degree),
      options:
    )
  end

  def build_harmonic_function_exercise(key_definition:)
    degree = sampled_degree(question_type: "harmonic_function", key_definition:)
    chord = chord_for_degree(key_definition:, degree:)
    options = FUNCTION_OPTIONS.shuffle(random: @random).map do |option|
      { id: option[:id], label: option[:label] }
    end

    build_common_exercise(
      question_type: "harmonic_function",
      key_definition:,
      chord:,
      correct_option_id: chord[:function_id],
      correct_option_label: chord[:function_label],
      signature: exercise_signature("harmonic_function", key_definition[:id], @chord_structure, degree, chord[:function_id]),
      options:
    )
  end

  def build_progression_exercise(key_definition:)
    template = sampled_progression_template(key_definition:)
    progression_chords = template[:sequence].map { |degree| chord_for_degree(key_definition:, degree:) }
    focus_position = sampled_progression_focus_position(template)
    correct_degree = template[:sequence].fetch(focus_position - 1)
    correct_chord = chord_for_degree(key_definition:, degree: correct_degree)
    distractor_degrees = ((1..7).to_a - [correct_degree]).sample(3, random: @random)
    options = ([correct_degree] + distractor_degrees).shuffle(random: @random).map do |degree|
      chord = chord_for_degree(key_definition:, degree:)
      { id: degree.to_s, label: degree_option_label(chord) }
    end

    {
      question_type: "progression",
      question_type_label: self.class.question_type_label("progression", @chord_structure),
      question: self.class.progression_question(focus_position),
      progression_template_id: template[:id],
      progression_focus_index: focus_position,
      key_id: key_definition[:id],
      key_label: key_definition[:label],
      chord_degree: correct_chord[:degree],
      chord_degree_label: correct_chord[:degree_card_label],
      chord_roman: correct_chord[:roman],
      chord_quality_id: correct_chord[:quality_id],
      chord_quality_label: correct_chord[:quality_label],
      chord_notes_label: correct_chord[:notes_label],
      chord_root_label: correct_chord[:root_label],
      chord_function_id: correct_chord[:function_id],
      chord_function_label: correct_chord[:function_label],
      prompt_label: "Ponto de escuta",
      prompt_value: ExercisePresentation.progression_prompt(focus_position),
      context_items: [
        { label: "Tonalidade", value: key_definition[:label] },
        { label: "Estrutura", value: self.class.chord_structure_definition(@chord_structure).fetch(:label) },
        { label: "Alvo", value: self.class.ordinal_label(focus_position) }
      ],
      progression_steps: ExercisePresentation.progression_steps(progression_chords.size, focus_position),
      audio_sequence: progression_chords.map { |chord| audio_payload_for(chord) },
      correct_option_id: correct_degree.to_s,
      correct_option_label: degree_option_label(correct_chord),
      signature: exercise_signature("progression", key_definition[:id], @chord_structure, template[:id], focus_position, correct_degree),
      options:
    }
  end

  def build_common_exercise(question_type:, key_definition:, chord:, correct_option_id:, correct_option_label:, signature:, options:)
    reference_chord = tonal_reference_needed?(question_type) ? chord_for_degree(key_definition:, degree: 1) : nil

    {
      question_type:,
      question_type_label: self.class.question_type_label(question_type, @chord_structure),
      question: self.class.question_prompt(question_type, @chord_structure),
      function_convention_id: HarmonicFunctionConvention::VERSION,
      key_id: key_definition[:id],
      key_label: key_definition[:label],
      chord_degree: chord[:degree],
      chord_degree_label: chord[:degree_card_label],
      chord_roman: chord[:roman],
      chord_quality_id: chord[:quality_id],
      chord_quality_label: chord[:quality_label],
      chord_notes_label: chord[:notes_label],
      chord_root_label: chord[:root_label],
      chord_function_id: chord[:function_id],
      chord_function_label: chord[:function_label],
      prompt_label: "Escuta",
      prompt_value: reference_prompt_value(reference_chord),
      context_items: common_context_items(question_type:, key_definition:, reference_chord:),
      audio_sequence: audio_sequence_for(question_type:, chord:, reference_chord:),
      correct_option_id:,
      correct_option_label:,
      signature:,
      options:
    }
  end

  def chord_for_degree(key_definition:, degree:)
    chord_cache[[key_definition[:id], @chord_structure, degree]] ||= begin
      scale_pitches = scale_for(key_definition).pitches(octaves: 3)
      indexes = @chord_structure == "tetrad" ? [degree - 1, degree + 1, degree + 3, degree + 5] : [degree - 1, degree + 1, degree + 3]
      chord_pitches = indexes.map { |index| scale_pitches.fetch(index) }
      pitch_collection = HeadMusic::Analysis::PitchCollection.new(chord_pitches)
      quality_id = pitch_collection.sonority.identifier.to_s
      quality_definition = self.class.quality_definition(@chord_structure, quality_id)
      root_label = self.class.localize_spelling(chord_pitches.first.spelling.to_s)
      inversion = @level == 4 ? @random.rand(1...chord_pitches.size) : 0
      if inversion.positive?
        notes = chord_pitches.map { |p| MusicTheory::Note.parse(p.to_s) }
        chord_pitches = notes.drop(inversion) + notes.take(inversion).map { |p| MusicTheory::Note.new(step: p.step, alter: p.alter, octave: p.octave + 1) }
      end
      register_offset = ExerciseInstrumentRegister.chord_offset(chord_pitches.map { |pitch| MusicTheory::Note.parse(pitch.to_s) }, @instrument)
      unless register_offset.zero?
        chord_pitches = chord_pitches.map do |pitch|
          note = MusicTheory::Note.parse(pitch.to_s)
          MusicTheory::Note.new(step: note.step, alter: note.alter, octave: note.octave + register_offset / 12)
        end
      end

      {
        degree:,
        register_offset:,
        inversion:,
        roman: roman_for_degree(degree),
        degree_card_label: "#{roman_for_degree(degree)} (#{degree}º grau)",
        quality_id:,
        quality_label: quality_definition.fetch(:label),
        quality_short_label: quality_definition.fetch(:short_label),
        function_id: function_for_degree(degree),
        function_label: self.class.function_definition(function_for_degree(degree)).fetch(:label),
        root_label:,
        notes_label: chord_pitches.map { |pitch| self.class.localize_spelling(pitch.spelling.to_s.sub(/-?\d+\z/, "")) }.join(" - "),
        pitches: chord_pitches.map(&:to_s),
        frequencies: chord_pitches.map { |pitch| pitch.frequency.round(3) }
      }
    end
  end

  def progression_option_label(chord)
    "#{chord[:roman]} · #{chord[:root_label]} #{chord[:quality_short_label]}"
  end

  def degree_option_label(chord)
    "#{chord[:roman]} (#{chord[:degree]}º grau)"
  end

  def audio_payload_for(chord)
    payload = {
      label: chord[:roman],
      pitches: chord[:pitches],
      frequencies: chord[:frequencies]
    }
    payload[:inversion] = chord[:inversion] if @level
    payload[:register_offset] = chord[:register_offset] unless @instrument == "piano"
    payload
  end

  def scale_for(key_definition)
    @scales ||= {}
    @scales[key_definition[:id]] ||= HeadMusic::Rudiment::Scale.get(key_definition[:root_pitch], "major")
  end

  def sampled_question_type
    candidates = if @question_mode == "mixed"
                   @level ? ListeningDifficulty.harmony_modes(@level) : QUESTION_MODES.reject { |mode| mode[:id] == "mixed" }.map { |mode| mode[:id] }
                 else
                   [@question_mode]
                 end

    recent_types = @recent_exercises.filter_map { |entry| entry[:question_type].presence }
    filtered_candidates = candidates - recent_types.last(2)
    (filtered_candidates.presence || candidates).sample(random: @random)
  end

  def sampled_key_definition
    recent_key_ids = @recent_exercises.filter_map { |entry| entry[:key_id].presence }
    pool = @level ? MAJOR_KEYS.select { |k| ListeningDifficulty.harmony_keys(@level).include?(k[:id]) } : MAJOR_KEYS
    candidates = pool.reject { |key| recent_key_ids.last(2).include?(key[:id]) }
    (candidates.presence || pool).sample(random: @random)
  end

  def sampled_degree(question_type:, key_definition:)
    recent_degrees = @recent_exercises.filter_map do |entry|
      next unless entry[:question_type] == question_type
      next unless entry[:key_id] == key_definition[:id]
      next unless entry[:chord_structure] == @chord_structure

      entry[:degree].presence&.to_i
    end

    candidates = degree_pool.reject { |degree| recent_degrees.last(3).include?(degree) }
    (candidates.presence || degree_pool).sample(random: @random)
  end

  def degree_pool = @level ? ListeningDifficulty.harmony_degrees(@level) : (1..7).to_a

  def sampled_progression_template(key_definition:)
    recent_template_ids = @recent_exercises.filter_map do |entry|
      next unless entry[:question_type] == "progression"
      next unless entry[:key_id] == key_definition[:id]
      next unless entry[:chord_structure] == @chord_structure

      entry[:progression_template_id].presence
    end

    pool = @level == 3 ? PROGRESSION_TEMPLATES.first(2) : PROGRESSION_TEMPLATES
    candidates = pool.reject { |template| recent_template_ids.last(2).include?(template[:id]) }
    (candidates.presence || pool).sample(random: @random)
  end

  def sampled_progression_focus_position(template)
    recent_positions = @recent_exercises.filter_map do |entry|
      next unless entry[:question_type] == "progression"
      next unless entry[:progression_template_id] == template[:id]

      entry[:progression_focus_index].presence&.to_i
    end

    positions = (1..template[:sequence].length).to_a
    candidates = positions.reject { |position| recent_positions.last(2).include?(position) }
    (candidates.presence || positions).sample(random: @random)
  end

  def common_context_items(question_type:, key_definition:, reference_chord: nil)
    items = [
      { label: "Tonalidade", value: key_definition[:label] },
      { label: "Estrutura", value: self.class.chord_structure_definition(@chord_structure).fetch(:label) }
    ]

    if question_type == "harmonic_function"
      items << { label: "Foco", value: "Função dentro da tonalidade" }
    elsif question_type == "scale_degree"
      items << { label: "Foco", value: "Grau do campo harmônico" }
    else
      items << { label: "Foco", value: @chord_structure == "tetrad" ? "Qualidade da tétrade" : "Qualidade da tríade" }
    end

    items << { label: "Referência", value: "#{reference_chord[:roman]} da tonalidade antes do alvo" } if tonal_reference_needed?(question_type) && reference_chord.present?

    items
  end

  def audio_sequence_for(question_type:, chord:, reference_chord:)
    return [audio_payload_for(reference_chord), audio_payload_for(chord)] if tonal_reference_needed?(question_type) && reference_chord.present?

    [audio_payload_for(chord)]
  end

  def reference_prompt_value(reference_chord)
    return "Acorde isolado" if reference_chord.blank?

    "Primeiro #{reference_chord[:roman]}, depois o acorde alvo"
  end

  def tonal_reference_needed?(question_type)
    %w[scale_degree harmonic_function].include?(question_type)
  end

  def chord_cache
    @chord_cache ||= {}
  end

  def function_for_degree(degree)
    FUNCTION_BY_DEGREE.fetch(degree)
  end

  def roman_for_degree(degree)
    (@chord_structure == "tetrad" ? TETRAD_ROMAN_NUMERALS : TRIAD_ROMAN_NUMERALS).fetch(degree)
  end

  def exercise_signature(*parts)
    parts.join("|")
  end

  def sanitize_question_mode(question_mode)
    question_mode = question_mode.to_s
    self.class.question_mode_ids.include?(question_mode) ? question_mode : DEFAULT_QUESTION_MODE
  end

  def sanitize_chord_structure(chord_structure)
    chord_structure = chord_structure.to_s
    self.class.chord_structure_ids.include?(chord_structure) ? chord_structure : DEFAULT_CHORD_STRUCTURE
  end
end
