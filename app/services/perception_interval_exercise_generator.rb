class PerceptionIntervalExerciseGenerator
  NOTE_LABELS = ExercisePresentation::NOTE_LABELS
  ACCIDENTAL_LABELS = ExercisePresentation::PITCH_ACCIDENTAL_LABELS
  DIRECTION_MODES = [
    { id: "ascending", label: "Ascendente" },
    { id: "descending", label: "Descendente" },
    { id: "mixed", label: "Misto" }
  ].freeze
  INSTRUMENTS = [
    { id: "piano", label: "Piano" },
    { id: "flute", label: "Flauta" },
    { id: "clarinet", label: "Clarinete" },
    { id: "guitar", label: "Violão" },
    { id: "organ", label: "Órgão" }
  ].freeze
  HARMONIC_INSTRUMENT_IDS = %w[piano guitar organ].freeze
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
    { id: "perfect_octave", label: "Oitava justa (P8)", head_music: :perfect_octave },
    { id: "minor_ninth", label: "Nona menor (m9)", head_music: :minor_ninth },
    { id: "major_ninth", label: "Nona maior (M9)", head_music: :major_ninth },
    { id: "minor_tenth", label: "Décima menor (m10)", head_music: :minor_tenth },
    { id: "major_tenth", label: "Décima maior (M10)", head_music: :major_tenth },
    { id: "perfect_eleventh", label: "Décima primeira justa (P11)", head_music: :perfect_eleventh },
    { id: "perfect_twelfth", label: "Décima segunda justa (P12)", head_music: :perfect_twelfth },
    { id: "minor_thirteenth", label: "Décima terceira menor (m13)", head_music: :minor_thirteenth },
    { id: "major_thirteenth", label: "Décima terceira maior (M13)", head_music: :major_thirteenth },
    { id: "minor_fourteenth", label: "Décima quarta menor (m14)", head_music: :minor_fourteenth },
    { id: "major_fourteenth", label: "Décima quarta maior (M14)", head_music: :major_fourteenth },
    { id: "perfect_fifteenth", label: "Décima quinta justa (P15)", head_music: :perfect_fifteenth }
  ].freeze
  REFERENCE_PITCHES = %w[A2 B2 C3 D3 E3 F3 G3 A3 B3 C4 D4 E4 F4 G4 A4 B4 C5 D5 E5].freeze
  MINIMUM_TARGET = MusicTheory::Note.parse("A2").midi
  MAXIMUM_TARGET = MusicTheory::Note.parse("C6").midi

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

  def self.instrument_definition(id)
    INSTRUMENTS.find { |instrument| instrument[:id] == id.to_s }
  end

  def self.harmonic_instrument?(instrument_id)
    HARMONIC_INSTRUMENT_IDS.include?(instrument_id.to_s)
  end

  def self.localize_pitch_name(pitch_name)
    ExercisePresentation.pitch_label(pitch_name)
  end

  def initialize(random: Random.new, direction_mode: DEFAULT_DIRECTION_MODE, instrument: DEFAULT_INSTRUMENT, recent_exercises: [], level: nil)
    @level = ListeningDifficulty.validate_level!(level) unless level.nil?
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
    written_interval = MusicTheory::Interval.new(from: reference_pitch, to: target_pitch)
    unless written_interval.name.tr(" ", "_") == interval_definition.fetch(:id) &&
           written_interval.written_direction == direction && written_interval.sounding_direction == direction
      raise ArgumentError, "transposition disagrees with the selected interval"
    end
    distractors = interval_pool.reject { |candidate| candidate[:id] == interval_definition[:id] }.sample(3, random: @random)
    options = ([interval_definition] + distractors).shuffle(random: @random).map do |definition|
      { id: definition[:id], label: definition[:label] }
    end

    exercise = {
      question: ExercisePresentation::INTERVAL_QUESTION,
      instrument: @instrument,
      instrument_label: instrument_label,
      direction_mode: @direction_mode,
      direction_mode_label: direction_mode_label,
      direction: direction.to_s,
      direction_label: direction_label(direction),
      reference_pitch: reference_pitch.spelling,
      target_pitch: target_pitch.spelling,
      reference_frequency: reference_pitch.frequency.round(3),
      target_frequency: target_pitch.frequency.round(3),
      correct_option_id: interval_definition[:id],
      correct_option_label: interval_definition[:label],
      correct_interval_name: written_interval.name,
      correct_interval_shorthand: written_interval.shorthand,
      signature: exercise_signature(
        interval_id: interval_definition[:id],
        direction: direction,
        reference_pitch: reference_pitch,
        target_pitch: target_pitch
      ),
      options:
    }
    exercise.merge!({ level: @level, difficulty_version: "perception-levels-v1" }) if @level
    exercise[:register_version] = "concert-register-v1" unless @instrument == "piano"
    exercise
  end

  private

  def interval_pool
    @level ? INTERVAL_LIBRARY.select { |i| ListeningDifficulty.intervals(@level).include?(i[:id]) } : INTERVAL_LIBRARY
  end

  def sampled_interval_definition
    candidates = interval_pool.reject { |definition| recent_interval_ids.include?(definition[:id]) }
    candidates = interval_pool if candidates.empty?
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
    names = %w[flute clarinet].include?(@instrument) ? (2..7).flat_map { |octave| %w[C D E F G A B].map { |step| "#{step}#{octave}" } } : REFERENCE_PITCHES
    register = ExerciseInstrumentRegister.range(@instrument)
    names.map { |name| MusicTheory::Note.parse(name) }.select do |reference_pitch|
      next false unless register.cover?(reference_pitch.midi)
      target_pitch = build_target_pitch(interval:, reference_pitch:, direction:)
      register.cover?(reference_pitch.midi) && register.cover?(target_pitch.midi) &&
        (%w[flute clarinet].include?(@instrument) || target_pitch.midi.between?(MINIMUM_TARGET, MAXIMUM_TARGET))
    end
  end

  def build_target_pitch(interval:, reference_pitch:, direction:)
    target = direction == :descending ? interval.below(reference_pitch.to_s) : interval.above(reference_pitch.to_s)
    MusicTheory::Note.parse(target.to_s)
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
      reference_pitch.spelling,
      target_pitch.spelling
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
