class ReadingNoteExerciseGenerator
  STAFF_POSITION_RANGE = (-6..14)
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
  NOTE_OPTIONS = ExercisePresentation::NOTE_LABELS.map { |letter, label| { id: letter.downcase, letter:, label: }.freeze }.freeze
  ACCIDENTALS = ExercisePresentation::ACCIDENTALS.map { |id, definition| definition.merge(id:).freeze }.freeze
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
    { id: "c_major", label: "Dó maior", accidental_kind: "natural", count: 0 },
    { id: "g_major", label: "Sol maior", accidental_kind: "sharp", count: 1 },
    { id: "d_major", label: "Ré maior", accidental_kind: "sharp", count: 2 },
    { id: "a_major", label: "Lá maior", accidental_kind: "sharp", count: 3 },
    { id: "e_major", label: "Mi maior", accidental_kind: "sharp", count: 4 },
    { id: "b_major", label: "Si maior", accidental_kind: "sharp", count: 5 },
    { id: "fs_major", label: "Fá sustenido maior", accidental_kind: "sharp", count: 6 },
    { id: "cs_major", label: "Dó sustenido maior", accidental_kind: "sharp", count: 7 },
    { id: "f_major", label: "Fá maior", accidental_kind: "flat", count: 1 },
    { id: "bb_major", label: "Si bemol maior", accidental_kind: "flat", count: 2 },
    { id: "eb_major", label: "Mi bemol maior", accidental_kind: "flat", count: 3 },
    { id: "ab_major", label: "Lá bemol maior", accidental_kind: "flat", count: 4 },
    { id: "db_major", label: "Ré bemol maior", accidental_kind: "flat", count: 5 },
    { id: "gb_major", label: "Sol bemol maior", accidental_kind: "flat", count: 6 },
    { id: "cb_major", label: "Dó bemol maior", accidental_kind: "flat", count: 7 }
  ].freeze
  SEASON_MODES = [
    {
      id: "level_1",
      label: "Nível 1",
      topics: [
        "Pauta musical",
        "Claves",
        "Símbolos básicos",
        "Organização visual da música",
        "Leitura inicial"
      ],
      staff_position_range: (0..8),
      accidental_ids: %w[sharp flat natural],
      key_signature_ids: %w[c_major g_major f_major]
    },
    {
      id: "level_2",
      label: "Nível 2",
      topics: [
        "Consolidação da leitura",
        "Figuras em contexto",
        "Relação entre leitura e compasso",
        "Leitura mais fluida"
      ],
      staff_position_range: (-2..10),
      accidental_ids: %w[sharp flat natural],
      key_signature_ids: %w[c_major g_major d_major f_major bb_major]
    },
    {
      id: "level_3",
      label: "Nível 3",
      topics: [
        "Leitura com mais complexidade rítmica",
        "Leitura associada à percepção e forma"
      ],
      staff_position_range: (-4..12),
      accidental_ids: %w[sharp flat natural double_sharp double_flat],
      key_signature_ids: %w[c_major g_major d_major a_major e_major f_major bb_major eb_major ab_major]
    },
    {
      id: "level_4",
      label: "Nível 4",
      topics: [
        "Leitura aplicada a contextos mais avançados",
        "Interpretação estrutural da escrita musical"
      ],
      staff_position_range: (-6..14),
      accidental_ids: %w[sharp flat natural double_sharp double_flat],
      key_signature_ids: KEY_SIGNATURES.map { |definition| definition[:id] }
    },
    {
      id: "mixed",
      label: "Misto",
      topics: [
        "Mistura todos os níveis e temporadas da plataforma"
      ]
    }
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
  DEFAULT_SEASON_MODE = "mixed".freeze
  DEFAULT_SEASON_ID = "level_4".freeze

  def self.clef_modes
    CLEF_MODES
  end

  def self.question_modes
    QUESTION_MODES
  end

  def self.season_modes
    SEASON_MODES
  end

  def self.clef_mode_ids
    CLEF_MODES.map { |mode| mode[:id] }
  end

  def self.question_mode_ids
    QUESTION_MODES.map { |mode| mode[:id] }
  end

  def self.season_mode_ids
    SEASON_MODES.map { |mode| mode[:id] }
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

  def self.season_mode_definition(id)
    SEASON_MODES.find { |mode| mode[:id] == id.to_s }
  end

  def self.season_definition(id)
    SEASON_MODES.find { |mode| mode[:id] == id.to_s && mode[:id] != DEFAULT_SEASON_MODE }
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

  def self.accidental_note_option_id(note_option_id:, accidental_id:)
    [note_option_id, accidental_id].join("__")
  end

  def self.accidental_note_option(id)
    note_option_id, accidental_id = id.to_s.split("__", 2)
    note_option = note_option(note_option_id)
    accidental = accidental_definition(accidental_id)
    return if note_option.blank? || accidental.blank?

    {
      id: accidental_note_option_id(note_option_id:, accidental_id:),
      note_option_id:,
      accidental_id:,
      label: [note_option[:label], accidental[:label].downcase].join(" ")
    }
  end

  def self.key_signature_definition(id)
    KEY_SIGNATURES.find { |definition| definition[:id] == id.to_s }
  end

  def self.localize_pitch_name(pitch_name)
    ExercisePresentation.pitch_label(pitch_name)
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

  def initialize(random: Random.new, clef_mode: DEFAULT_CLEF_MODE, question_mode: DEFAULT_QUESTION_MODE, season_mode: DEFAULT_SEASON_MODE, recent_exercises: [])
    @random = random
    @clef_mode = sanitize_clef_mode(clef_mode)
    @question_mode = sanitize_question_mode(question_mode)
    @season_mode = sanitize_season_mode(season_mode)
    @recent_exercises = Array(recent_exercises).map { |entry| entry.to_h.symbolize_keys }
  end

  def call
    season_definition = sampled_season_definition
    question_type = sampled_question_type
    clef_definition = sampled_clef_definition
    clef = HeadMusic::Rudiment::Clef.get(clef_definition[:head_music])

    exercise = case question_type
               when "note_name"
                 build_note_name_exercise(clef_definition:, clef:, question_type:, season_definition:)
               when "accidental"
                 build_accidental_exercise(clef_definition:, clef:, question_type:, season_definition:)
               else
                 build_key_signature_exercise(clef_definition:, question_type:, season_definition:)
               end

    exercise.merge(
      question_mode: @question_mode,
      question_mode_label: question_mode_label
    )
  end

  private

  def build_note_name_exercise(clef_definition:, clef:, question_type:, season_definition:)
    staff_position_index = sampled_staff_position_index(clef_definition:, clef:, question_type:, season_definition:)
    pitch = pitch_for_staff_position(clef:, staff_position_index:)
    note_definition = note_definition_for_pitch(pitch)
    distractors = NOTE_OPTIONS.reject { |option| option[:id] == note_definition[:id] }.sample(3, random: @random)
    options = ([note_definition] + distractors).shuffle(random: @random).map do |option|
      { id: option[:id], label: option[:label] }
    end

    build_common_exercise(
      question_type:,
      season_definition:,
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

  def build_accidental_exercise(clef_definition:, clef:, question_type:, season_definition:)
    staff_position_index = sampled_staff_position_index(clef_definition:, clef:, question_type:, season_definition:)
    pitch = pitch_for_staff_position(clef:, staff_position_index:)
    accidental_definition = sampled_accidental_definition(clef_definition:, pitch_name: pitch.to_s, staff_position_index:, season_definition:)
    written_note = pitch.with_alter(accidental_definition.fetch(:alter))
    note_definition = note_definition_for_pitch(written_note)
    correct_option = self.class.accidental_note_option(
      self.class.accidental_note_option_id(note_option_id: note_definition[:id], accidental_id: accidental_definition[:id])
    )
    distractors = accidental_note_options_for(season_definition)
      .reject { |option| option[:id] == correct_option[:id] }
      .sample(3, random: @random)
    options = ([correct_option] + distractors).shuffle(random: @random).map do |option|
      { id: option[:id], label: option[:label] }
    end

    build_common_exercise(
      question_type:,
      season_definition:,
      question: "Observe a nota na pauta e identifique a nota completa com o acidente musical indicado.",
      clef_definition:,
      correct_option_id: correct_option[:id],
      correct_option_label: correct_option[:label],
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

  def build_key_signature_exercise(clef_definition:, question_type:, season_definition:)
    key_signature_definition = sampled_key_signature_definition(clef_definition:, question_type:, season_definition:)
    distractors = KEY_SIGNATURES.reject { |definition| definition[:id] == key_signature_definition[:id] }.sample(3, random: @random)
    options = ([key_signature_definition] + distractors).shuffle(random: @random).map do |definition|
      { id: definition[:id], label: definition[:label] }
    end

    build_common_exercise(
      question_type:,
      season_definition:,
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

  def build_common_exercise(question_type:, season_definition:, question:, clef_definition:, correct_option_id:, correct_option_label:, signature:, options:, **attributes)
    question_type_definition = self.class.question_type_definition(question_type)

    {
      question:,
      question_type:,
      question_type_label: question_type_definition.fetch(:label),
      season_mode: @season_mode,
      season_mode_label: season_mode_label,
      season_id: season_definition[:id],
      season_label: season_definition[:label],
      season_topics: season_definition[:topics],
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

  def sampled_season_definition
    return self.class.season_definition(@season_mode) unless @season_mode == DEFAULT_SEASON_MODE

    recent_season_ids = @recent_exercises.filter_map { |entry| entry[:season_id].presence }.last(1)
    candidates = available_seasons.reject { |season| recent_season_ids.include?(season[:id]) }
    (candidates.presence || available_seasons).sample(random: @random)
  end

  def sampled_staff_position_index(clef_definition:, clef:, question_type:, season_definition:)
    candidates = season_definition.fetch(:staff_position_range, STAFF_POSITION_RANGE).to_a
    filtered_candidates = candidates.reject do |staff_position_index|
      recent_staff_positions_for(clef_definition[:id], season_definition[:id]).include?(staff_position_index)
    end

    (filtered_candidates.presence || candidates).sample(random: @random)
  end

  def sampled_accidental_definition(clef_definition:, pitch_name:, staff_position_index:, season_definition:)
    candidates = allowed_accidentals_for(season_definition).reject do |accidental|
      recent_accidental_ids_for(clef_definition[:id], season_definition[:id], staff_position_index).include?(accidental[:id])
    end

    (candidates.presence || allowed_accidentals_for(season_definition)).sample(random: @random)
  end

  def sampled_key_signature_definition(clef_definition:, question_type:, season_definition:)
    allowed_key_signatures = allowed_key_signatures_for(season_definition)
    candidates = allowed_key_signatures.reject do |definition|
      recent_key_signature_ids_for(clef_definition[:id], question_type, season_definition[:id]).include?(definition[:id])
    end

    (candidates.presence || allowed_key_signatures).sample(random: @random)
  end

  def pitch_for_staff_position(clef:, staff_position_index:)
    pitch = if staff_position_index.even?
              clef.pitch_for_line((staff_position_index / 2) + 1)
            else
              clef.pitch_for_space(((staff_position_index - 1) / 2) + 1)
            end
    MusicTheory::Note.parse(pitch.to_s)
  end

  def note_definition_for_pitch(pitch)
    self.class.note_option_for_letter(pitch.step)
  end

  def recent_staff_positions_for(clef_id, season_id)
    @recent_staff_positions_by_context ||= @recent_exercises.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |entry, positions|
      next if entry[:clef_id].blank?
      next if entry[:season_id].blank?
      next if entry[:staff_position_index].blank?
      next unless %w[note_name accidental].include?(entry[:question_type])

      key = [entry[:clef_id], entry[:season_id]]
      positions[key] << entry[:staff_position_index].to_i
    end

    @recent_staff_positions_by_context[[clef_id, season_id]]
  end

  def recent_accidental_ids_for(clef_id, season_id, staff_position_index)
    @recent_accidentals_by_context ||= @recent_exercises.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |entry, accidental_ids|
      next if entry[:clef_id].blank?
      next if entry[:season_id].blank?
      next unless entry[:question_type] == "accidental"
      next if entry[:staff_position_index].blank? || entry[:note_accidental_id].blank?

      key = [entry[:clef_id], entry[:season_id], entry[:staff_position_index].to_i]
      accidental_ids[key] << entry[:note_accidental_id]
    end

    @recent_accidentals_by_context[[clef_id, season_id, staff_position_index.to_i]]
  end

  def recent_key_signature_ids_for(clef_id, _question_type, season_id)
    @recent_key_signatures_by_context ||= @recent_exercises.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |entry, key_signature_ids|
      next if entry[:clef_id].blank?
      next if entry[:season_id].blank?
      next unless entry[:question_type] == "key_signature"
      next if entry[:key_signature_id].blank?

      key = [entry[:clef_id], entry[:season_id]]
      key_signature_ids[key] << entry[:key_signature_id]
    end

    @recent_key_signatures_by_context[[clef_id, season_id]]
  end

  def clef_mode_label
    self.class.clef_mode_definition(@clef_mode).fetch(:label)
  end

  def season_mode_label
    self.class.season_mode_definition(@season_mode).fetch(:label)
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

  def sanitize_season_mode(season_mode)
    season_mode = season_mode.to_s
    self.class.season_mode_ids.include?(season_mode) ? season_mode : DEFAULT_SEASON_MODE
  end

  def available_seasons
    @available_seasons ||= SEASON_MODES.reject { |mode| mode[:id] == DEFAULT_SEASON_MODE }
  end

  def allowed_accidentals_for(season_definition)
    accidental_ids = season_definition.fetch(:accidental_ids, ACCIDENTALS.map { |accidental| accidental[:id] })
    ACCIDENTALS.select { |accidental| accidental_ids.include?(accidental[:id]) }
  end

  def allowed_key_signatures_for(season_definition)
    key_signature_ids = season_definition.fetch(:key_signature_ids, KEY_SIGNATURES.map { |definition| definition[:id] })
    KEY_SIGNATURES.select { |definition| key_signature_ids.include?(definition[:id]) }
  end

  def accidental_note_options_for(season_definition)
    allowed_accidentals_for(season_definition).flat_map do |accidental|
      NOTE_OPTIONS.map do |note_option|
        self.class.accidental_note_option(
          self.class.accidental_note_option_id(note_option_id: note_option[:id], accidental_id: accidental[:id])
        )
      end
    end
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
