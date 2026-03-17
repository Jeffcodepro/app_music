class PerceptionIntervalExerciseGenerator
  NOTE_LABELS = {
    "C" => "Dó",
    "D" => "Ré",
    "E" => "Mi",
    "F" => "Fá",
    "G" => "Sol",
    "A" => "Lá",
    "B" => "Si"
  }.freeze
  ACCIDENTAL_LABELS = {
    "#" => "sustenido",
    "##" => "duplo sustenido",
    "b" => "bemol",
    "bb" => "duplo bemol"
  }.freeze
  DIRECTION_MODES = [
    { id: "ascending", label: "Crescente" },
    { id: "descending", label: "Decrescente" },
    { id: "mixed", label: "Misto" }
  ].freeze
  INSTRUMENTS = [
    { id: "piano", label: "Piano" },
    { id: "flute", label: "Flauta" },
    { id: "clarinet", label: "Clarinete" },
    { id: "guitar", label: "Violão" },
    { id: "organ", label: "Órgão" }
  ].freeze
  DEFAULT_DIRECTION_MODE = "mixed".freeze
  DEFAULT_INSTRUMENT = "piano".freeze
  INTERVAL_LIBRARY = [
    { id: "minor_second", label: "Segunda menor (m2)", head_music: :minor_second },
    { id: "major_second", label: "Segunda maior (M2)", head_music: :major_second },
    { id: "minor_third", label: "Terça menor (m3)", head_music: :minor_third },
    { id: "major_third", label: "Terça maior (M3)", head_music: :major_third },
    { id: "perfect_fourth", label: "Quarta justa (P4)", head_music: :perfect_fourth },
    { id: "perfect_fifth", label: "Quinta justa (P5)", head_music: :perfect_fifth },
    { id: "minor_sixth", label: "Sexta menor (m6)", head_music: :minor_sixth },
    { id: "major_sixth", label: "Sexta maior (M6)", head_music: :major_sixth },
    { id: "minor_seventh", label: "Sétima menor (m7)", head_music: :minor_seventh },
    { id: "major_seventh", label: "Sétima maior (M7)", head_music: :major_seventh },
    { id: "perfect_octave", label: "Oitava justa (P8)", head_music: :perfect_octave }
  ].freeze
  REFERENCE_PITCHES = %w[C3 D3 E3 F3 G3 A3 B3 C4 D4 E4 F4 G4 A4 B4 C5 D5].freeze
  MINIMUM_TARGET = HeadMusic::Rudiment::Pitch.get("C3").midi
  MAXIMUM_TARGET = HeadMusic::Rudiment::Pitch.get("A5").midi

  def self.direction_modes
    DIRECTION_MODES
  end

  def self.instruments
    INSTRUMENTS
  end

  def self.direction_mode_ids
    DIRECTION_MODES.map { |mode| mode[:id] }
  end

  def self.instrument_ids
    INSTRUMENTS.map { |instrument| instrument[:id] }
  end

  def self.localize_pitch_name(pitch_name)
    match_data = pitch_name.to_s.match(/\A([A-G])(bb|##|b|#)?(-?\d+)\z/)
    return pitch_name.to_s if match_data.blank?

    note = NOTE_LABELS.fetch(match_data[1])
    accidental = ACCIDENTAL_LABELS[match_data[2]]
    octave = match_data[3]

    [note, accidental, octave].compact.join(" ")
  end

  def initialize(random: Random.new, direction_mode: DEFAULT_DIRECTION_MODE, instrument: DEFAULT_INSTRUMENT, recent_exercises: [])
    @random = random
    @direction_mode = sanitize_direction_mode(direction_mode)
    @instrument = sanitize_instrument(instrument)
    @recent_exercises = Array(recent_exercises).map { |entry| entry.to_h.symbolize_keys }
  end

  def call
    interval_definition = sampled_interval_definition
    interval = HeadMusic::Analysis::DiatonicInterval.get(interval_definition[:head_music])
    direction = selected_direction
    reference_pitch = sampled_reference_pitch(interval:, direction:, interval_definition:)
    target_pitch = build_target_pitch(interval:, reference_pitch:, direction:)
    distractors = INTERVAL_LIBRARY.reject { |candidate| candidate[:id] == interval_definition[:id] }.sample(3, random: @random)
    options = ([interval_definition] + distractors).shuffle(random: @random).map do |definition|
      { id: definition[:id], label: definition[:label] }
    end

    {
      question: "Ouça duas notas consecutivas e identifique o intervalo melódico.",
      instrument: @instrument,
      instrument_label: instrument_label,
      direction_mode: @direction_mode,
      direction_mode_label: direction_mode_label,
      direction: direction.to_s,
      direction_label: direction_label(direction),
      reference_pitch: reference_pitch.to_s,
      target_pitch: target_pitch.to_s,
      reference_frequency: reference_pitch.frequency.round(3),
      target_frequency: target_pitch.frequency.round(3),
      correct_option_id: interval_definition[:id],
      correct_option_label: interval_definition[:label],
      correct_interval_name: interval.name,
      correct_interval_shorthand: interval.shorthand,
      signature: exercise_signature(
        interval_id: interval_definition[:id],
        direction: direction,
        reference_pitch: reference_pitch,
        target_pitch: target_pitch
      ),
      options:
    }
  end

  private

  def sampled_interval_definition
    candidates = INTERVAL_LIBRARY.reject { |definition| recent_interval_ids.include?(definition[:id]) }
    candidates = INTERVAL_LIBRARY if candidates.empty?
    candidates.sample(random: @random)
  end

  def sampled_reference_pitch(interval:, direction:, interval_definition:)
    candidates = eligible_reference_pitches(interval:, direction:)
    filtered_candidates = candidates.reject do |reference_pitch|
      target_pitch = build_target_pitch(interval:, reference_pitch:, direction:)
      recent_signatures.include?(
        exercise_signature(
          interval_id: interval_definition[:id],
          direction: direction,
          reference_pitch: reference_pitch,
          target_pitch: target_pitch
        )
      )
    end

    (filtered_candidates.presence || candidates).sample(random: @random)
  end

  def selected_direction
    return @direction_mode.to_sym if %w[ascending descending].include?(@direction_mode)

    %i[ascending descending].sample(random: @random)
  end

  def eligible_reference_pitches(interval:, direction:)
    REFERENCE_PITCHES.map { |name| HeadMusic::Rudiment::Pitch.get(name) }.select do |reference_pitch|
      target_pitch = build_target_pitch(interval:, reference_pitch:, direction:)
      target_pitch.midi.between?(MINIMUM_TARGET, MAXIMUM_TARGET)
    end
  end

  def build_target_pitch(interval:, reference_pitch:, direction:)
    direction == :descending ? interval.below(reference_pitch) : interval.above(reference_pitch)
  end

  def direction_label(direction)
    direction == :descending ? "Decrescente" : "Crescente"
  end

  def direction_mode_label
    DIRECTION_MODES.find { |mode| mode[:id] == @direction_mode }.fetch(:label)
  end

  def instrument_label
    INSTRUMENTS.find { |option| option[:id] == @instrument }.fetch(:label)
  end

  def recent_interval_ids
    @recent_interval_ids ||= @recent_exercises.filter_map { |entry| entry[:interval_id].presence }
  end

  def recent_signatures
    @recent_signatures ||= @recent_exercises.filter_map { |entry| entry[:signature].presence }
  end

  def exercise_signature(interval_id:, direction:, reference_pitch:, target_pitch:)
    [
      interval_id,
      direction,
      reference_pitch.to_s,
      target_pitch.to_s
    ].join("|")
  end

  def sanitize_direction_mode(direction_mode)
    direction_mode = direction_mode.to_s
    self.class.direction_mode_ids.include?(direction_mode) ? direction_mode : DEFAULT_DIRECTION_MODE
  end

  def sanitize_instrument(instrument)
    instrument = instrument.to_s
    self.class.instrument_ids.include?(instrument) ? instrument : DEFAULT_INSTRUMENT
  end
end
