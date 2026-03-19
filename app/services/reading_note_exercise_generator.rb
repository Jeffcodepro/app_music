class ReadingNoteExerciseGenerator
  QUESTION_MODES = [
    { id: "note_name", label: "Notas" },
    { id: "accidental", label: "Acidentes" },
    { id: "key_signature", label: "Armadura" },
    { id: "mixed", label: "Misto" }
  ].freeze
  QUESTION_TYPES = [
    { id: "note_name", label: "Nome da nota" },
    { id: "accidental", label: "Acidente da nota" },
    { id: "key_signature", label: "Tonalidade da armadura" }
  ].freeze
  NOTE_OPTIONS = [
    { id: "c", letter: "C", label: "Dó" },
    { id: "d", letter: "D", label: "Ré" },
    { id: "e", letter: "E", label: "Mi" },
    { id: "f", letter: "F", label: "Fá" },
    { id: "g", letter: "G", label: "Sol" },
    { id: "a", letter: "A", label: "Lá" },
    { id: "b", letter: "B", label: "Si" }
  ].freeze
  ACCIDENTALS = [
    { id: "sharp", label: "Sustenido", symbol: "♯" },
    { id: "flat", label: "Bemol", symbol: "♭" },
    { id: "natural", label: "Bequadro", symbol: "♮" },
    { id: "double_sharp", label: "Duplo sustenido", symbol: "𝄪" }
  ].freeze
  CLEFS = [
    {
      id: "treble",
      label: "Clave de Sol",
      head_music: "treble_clef",
      symbol: "𝄞",
      symbol_label: "Sol"
    },
    {
      id: "bass",
      label: "Clave de Fá",
      head_music: "bass_clef",
      symbol: "𝄢",
      symbol_label: "Fá"
    },
    {
      id: "alto",
      label: "Clave de Dó",
      head_music: "alto_clef",
      symbol: "𝄡",
      symbol_label: "Dó"
    }
  ].freeze
  CLEF_MODES = [
    { id: "treble", label: "Somente Sol" },
    { id: "bass", label: "Somente Fá" },
    { id: "alto", label: "Somente Dó" },
    { id: "mixed", label: "Misto" }
  ].freeze
  KEY_SIGNATURES = [
    { id: "g_major", label: "Sol maior", accidental_kind: "sharp", count: 1 },
    { id: "d_major", label: "Ré maior", accidental_kind: "sharp", count: 2 },
    { id: "a_major", label: "Lá maior", accidental_kind: "sharp", count: 3 },
    { id: "e_major", label: "Mi maior", accidental_kind: "sharp", count: 4 },
    { id: "f_major", label: "Fá maior", accidental_kind: "flat", count: 1 },
    { id: "bb_major", label: "Si bemol maior", accidental_kind: "flat", count: 2 },
    { id: "eb_major", label: "Mi bemol maior", accidental_kind: "flat", count: 3 },
    { id: "ab_major", label: "Lá bemol maior", accidental_kind: "flat", count: 4 }
  ].freeze
  KEY_SIGNATURE_PITCHES = {
    "treble" => {
      "sharp" => %w[F5 C5 G5 D5 A4 E5 B4],
      "flat" => %w[B4 E5 A4 D5 G4 C5 F4]
    },
    "bass" => {
      "sharp" => %w[F3 C3 G3 D3 A2 E3 B2],
      "flat" => %w[B2 E3 A2 D3 G2 C3 F2]
    },
    "alto" => {
      "sharp" => %w[F4 C4 G4 D4 A3 E4 B3],
      "flat" => %w[B3 E4 A3 D4 G3 C4 F3]
    }
  }.freeze
  DEFAULT_CLEF_MODE = "mixed".freeze
  DEFAULT_QUESTION_MODE = "mixed".freeze
  STAFF_POSITION_RANGE = (-2..10)

  def self.clef_modes
    CLEF_MODES
  end

  def self.question_modes
    QUESTION_MODES
  end

  def self.clef_mode_ids
    CLEF_MODES.map { |mode| mode[:id] }
  end

  def self.question_mode_ids
    QUESTION_MODES.map { |mode| mode[:id] }
  end

  def self.clef_definition(id)
    CLEFS.find { |clef| clef[:id] == id.to_s }
  end

  def self.clef_mode_definition(id)
    CLEF_MODES.find { |mode| mode[:id] == id.to_s }
  end

  def self.question_mode_definition(id)
    QUESTION_MODES.find { |mode| mode[:id] == id.to_s }
  end

  def self.question_type_definition(id)
    QUESTION_TYPES.find { |type| type[:id] == id.to_s }
  end

  def self.note_option(id)
    NOTE_OPTIONS.find { |option| option[:id] == id.to_s }
  end

  def self.note_option_for_letter(letter)
    NOTE_OPTIONS.find { |option| option[:letter] == letter.to_s }
  end

  def self.accidental_definition(id)
    ACCIDENTALS.find { |accidental| accidental[:id] == id.to_s }
  end

  def self.key_signature_definition(id)
    KEY_SIGNATURES.find { |definition| definition[:id] == id.to_s }
  end

  def self.localize_pitch_name(pitch_name)
    match_data = pitch_name.to_s.match(/\A([A-G])(bb|##|b|#)?(-?\d+)\z/)
    return pitch_name.to_s if match_data.blank?

    note = note_option_for_letter(match_data[1])&.fetch(:label)
    accidental = {
      "#" => "sustenido",
      "##" => "duplo sustenido",
      "b" => "bemol",
      "bb" => "duplo bemol"
    }[match_data[2]]

    [note, accidental, match_data[3]].compact.join(" ")
  end

  def self.key_signature_accidentals_for(clef_id, key_signature_id)
    key_signature = key_signature_definition(key_signature_id)
    pitch_names = KEY_SIGNATURE_PITCHES.dig(clef_id.to_s, key_signature&.dig(:accidental_kind))
    return [] if key_signature.blank? || pitch_names.blank?

    clef = HeadMusic::Rudiment::Clef.get(clef_definition(clef_id).fetch(:head_music))
    accidental = accidental_definition(key_signature[:accidental_kind])

    pitch_names.first(key_signature[:count]).filter_map do |pitch_name|
      staff_position_index = staff_position_index_for_pitch(clef:, pitch_name:)
      next if staff_position_index.blank?

      {
        accidental_id: accidental[:id],
        symbol: accidental[:symbol],
        staff_position_index:
      }
    end
  end

  def initialize(random: Random.new, clef_mode: DEFAULT_CLEF_MODE, question_mode: DEFAULT_QUESTION_MODE, recent_exercises: [])
    @random = random
    @clef_mode = sanitize_clef_mode(clef_mode)
    @question_mode = sanitize_question_mode(question_mode)
    @recent_exercises = Array(recent_exercises).map { |entry| entry.to_h.symbolize_keys }
  end

  def call
    question_type = sampled_question_type
    clef_definition = sampled_clef_definition
    clef = HeadMusic::Rudiment::Clef.get(clef_definition[:head_music])

    exercise = case question_type
               when "note_name"
                 build_note_name_exercise(clef_definition:, clef:, question_type:)
               when "accidental"
                 build_accidental_exercise(clef_definition:, clef:, question_type:)
               else
                 build_key_signature_exercise(clef_definition:, question_type:)
               end

    exercise.merge(
      question_mode: @question_mode,
      question_mode_label: question_mode_label
    )
  end

  private

  def build_note_name_exercise(clef_definition:, clef:, question_type:)
    staff_position_index = sampled_staff_position_index(clef_definition:, clef:, question_type:)
    pitch = pitch_for_staff_position(clef:, staff_position_index:)
    note_definition = note_definition_for_pitch(pitch)
    distractors = NOTE_OPTIONS.reject { |option| option[:id] == note_definition[:id] }.sample(3, random: @random)
    options = ([note_definition] + distractors).shuffle(random: @random).map do |option|
      { id: option[:id], label: option[:label] }
    end

    build_common_exercise(
      question_type:,
      question: "Observe a pauta e identifique a nota escrita.",
      clef_definition:,
      correct_option_id: note_definition[:id],
      correct_option_label: note_definition[:label],
      signature: self.class.exercise_signature(question_type:, clef_id: clef_definition[:id], pitch_name: pitch.to_s),
      options:,
      staff_position_index:,
      pitch_name: pitch.to_s,
      pitch_label: self.class.localize_pitch_name(pitch.to_s),
      notation_kind: "note"
    )
  end

  def build_accidental_exercise(clef_definition:, clef:, question_type:)
    staff_position_index = sampled_staff_position_index(clef_definition:, clef:, question_type:)
    pitch = pitch_for_staff_position(clef:, staff_position_index:)
    accidental_definition = sampled_accidental_definition(clef_definition:, pitch_name: pitch.to_s, staff_position_index:)
    options = ACCIDENTALS.shuffle(random: @random).map do |accidental|
      { id: accidental[:id], label: accidental[:label] }
    end

    build_common_exercise(
      question_type:,
      question: "Observe a nota na pauta e identifique o acidente musical indicado.",
      clef_definition:,
      correct_option_id: accidental_definition[:id],
      correct_option_label: accidental_definition[:label],
      signature: self.class.exercise_signature(
        question_type:,
        clef_id: clef_definition[:id],
        pitch_name: pitch.to_s,
        accidental_id: accidental_definition[:id]
      ),
      options:,
      staff_position_index:,
      pitch_name: pitch.to_s,
      pitch_label: self.class.localize_pitch_name(pitch.to_s),
      note_accidental_id: accidental_definition[:id],
      note_accidental_label: accidental_definition[:label],
      note_accidental_symbol: accidental_definition[:symbol],
      notation_kind: "note"
    )
  end

  def build_key_signature_exercise(clef_definition:, question_type:)
    key_signature_definition = sampled_key_signature_definition(clef_definition:, question_type:)
    distractors = KEY_SIGNATURES.reject { |definition| definition[:id] == key_signature_definition[:id] }.sample(3, random: @random)
    options = ([key_signature_definition] + distractors).shuffle(random: @random).map do |definition|
      { id: definition[:id], label: definition[:label] }
    end

    build_common_exercise(
      question_type:,
      question: "Observe a armadura de clave e identifique a tonalidade maior correspondente.",
      clef_definition:,
      correct_option_id: key_signature_definition[:id],
      correct_option_label: key_signature_definition[:label],
      signature: self.class.exercise_signature(question_type:, clef_id: clef_definition[:id], key_signature_id: key_signature_definition[:id]),
      options:,
      key_signature_id: key_signature_definition[:id],
      key_signature_label: key_signature_definition[:label],
      key_signature_accidentals: self.class.key_signature_accidentals_for(clef_definition[:id], key_signature_definition[:id]),
      notation_kind: "key_signature"
    )
  end

  def build_common_exercise(question_type:, question:, clef_definition:, correct_option_id:, correct_option_label:, signature:, options:, **attributes)
    question_type_definition = self.class.question_type_definition(question_type)

    {
      question:,
      question_type:,
      question_type_label: question_type_definition.fetch(:label),
      clef_mode: @clef_mode,
      clef_mode_label: clef_mode_label,
      clef_id: clef_definition[:id],
      clef_label: clef_definition[:label],
      clef_symbol: clef_definition[:symbol],
      clef_symbol_label: clef_definition[:symbol_label],
      head_music_clef: clef_definition[:head_music],
      correct_option_id:,
      correct_option_label:,
      signature:,
      options:
    }.merge(attributes)
  end

  def sampled_question_type
    return @question_mode unless @question_mode == "mixed"

    recent_question_types = @recent_exercises.filter_map { |entry| entry[:question_type].presence }.last(1)
    candidates = QUESTION_TYPES.reject { |type| recent_question_types.include?(type[:id]) }
    (candidates.presence || QUESTION_TYPES).sample(random: @random).fetch(:id)
  end

  def sampled_clef_definition
    return self.class.clef_definition(@clef_mode) unless @clef_mode == "mixed"

    recent_clef_ids = @recent_exercises.filter_map { |entry| entry[:clef_id].presence }.last(1)
    candidates = CLEFS.reject { |clef| recent_clef_ids.include?(clef[:id]) }
    (candidates.presence || CLEFS).sample(random: @random)
  end

  def sampled_staff_position_index(clef_definition:, clef:, question_type:)
    candidates = STAFF_POSITION_RANGE.to_a
    filtered_candidates = candidates.reject do |staff_position_index|
      pitch = pitch_for_staff_position(clef:, staff_position_index:)
      recent_signatures.include?(
        self.class.exercise_signature(question_type:, clef_id: clef_definition[:id], pitch_name: pitch.to_s)
      ) || recent_staff_positions_for(clef_definition[:id]).include?(staff_position_index)
    end

    (filtered_candidates.presence || candidates).sample(random: @random)
  end

  def sampled_accidental_definition(clef_definition:, pitch_name:, staff_position_index:)
    candidates = ACCIDENTALS.reject do |accidental|
      recent_signatures.include?(
        self.class.exercise_signature(
          question_type: "accidental",
          clef_id: clef_definition[:id],
          pitch_name:,
          accidental_id: accidental[:id]
        )
      ) && recent_staff_positions_for(clef_definition[:id]).include?(staff_position_index)
    end

    (candidates.presence || ACCIDENTALS).sample(random: @random)
  end

  def sampled_key_signature_definition(clef_definition:, question_type:)
    candidates = KEY_SIGNATURES.reject do |definition|
      recent_signatures.include?(
        self.class.exercise_signature(question_type:, clef_id: clef_definition[:id], key_signature_id: definition[:id])
      )
    end

    (candidates.presence || KEY_SIGNATURES).sample(random: @random)
  end

  def pitch_for_staff_position(clef:, staff_position_index:)
    if staff_position_index.even?
      clef.pitch_for_line((staff_position_index / 2) + 1)
    else
      clef.pitch_for_space(((staff_position_index - 1) / 2) + 1)
    end
  end

  def note_definition_for_pitch(pitch)
    letter = pitch.to_s.match(/\A([A-G])/)&.captures&.first
    self.class.note_option_for_letter(letter) || NOTE_OPTIONS.first
  end

  def recent_signatures
    @recent_signatures ||= @recent_exercises.filter_map { |entry| entry[:signature].presence }
  end

  def recent_staff_positions_for(clef_id)
    @recent_staff_positions_by_clef ||= @recent_exercises.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |entry, positions|
      next if entry[:clef_id].blank?
      next if entry[:staff_position_index].blank?

      positions[entry[:clef_id]] << entry[:staff_position_index].to_i
      positions[entry[:clef_id]] = positions[entry[:clef_id]].last(2)
    end

    @recent_staff_positions_by_clef[clef_id]
  end

  def clef_mode_label
    self.class.clef_mode_definition(@clef_mode).fetch(:label)
  end

  def question_mode_label
    self.class.question_mode_definition(@question_mode).fetch(:label)
  end

  def sanitize_clef_mode(clef_mode)
    clef_mode = clef_mode.to_s
    self.class.clef_mode_ids.include?(clef_mode) ? clef_mode : DEFAULT_CLEF_MODE
  end

  def sanitize_question_mode(question_mode)
    question_mode = question_mode.to_s
    self.class.question_mode_ids.include?(question_mode) ? question_mode : DEFAULT_QUESTION_MODE
  end

  def self.exercise_signature(question_type:, clef_id:, pitch_name: nil, accidental_id: nil, key_signature_id: nil)
    [question_type, clef_id, pitch_name, accidental_id, key_signature_id].compact.join("|")
  end

  def self.staff_position_index_for_pitch(clef:, pitch_name:)
    STAFF_POSITION_RANGE.find do |staff_position_index|
      pitch = if staff_position_index.even?
                clef.pitch_for_line((staff_position_index / 2) + 1)
              else
                clef.pitch_for_space(((staff_position_index - 1) / 2) + 1)
              end

      pitch.to_s == pitch_name.to_s
    end
  end
end
