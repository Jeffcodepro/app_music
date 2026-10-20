class VoicedDictationIntegrityValidator
  NATURAL = { "C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "B" => 11 }.freeze
  def self.validate!(exercise) = new(exercise).validate!
  def initialize(exercise) = @e = exercise.to_h.deep_symbolize_keys

  def validate!
    check(%w[voices-v1 voices-v2].include?(@e[:dictation_format]))
    level = @e[:level]
    check(level.is_a?(Integer) && (1..4).cover?(level))
    count = @e[:voice_count]
    check(count.is_a?(Integer) && (level < 3 ? count == 1 : (level == 3 ? count == 2 : [3,4].include?(count))))
    modern = @e[:dictation_format] == "voices-v2"
    check(@e[:instrument] == "piano") if modern && level == 4
    @octaves = { 1 => [4], 2 => modern && %w[flute clarinet].include?(@e[:instrument]) ? [5,4] : [4,3], 3 => modern ? [5,4,3] : [4,3,2], 4 => [5,4,3,2] }.fetch(count)
    @level, @bars = level, level < 3 ? 1 : 2
    check(@e.values_at(:measure_count, :total_steps, :bpm_unit_steps, :tempo_bpm) == [@bars, @bars * 16, 4, 80])
    check(%i[measure_count total_steps bpm_unit_steps tempo_bpm].all? { |key| @e[key].is_a?(Integer) })
    check(@e.values_at(:question_mode, :question_type) == ["melodic_dictation"] * 2)
    check(@e[:question] == "Qual partitura você ouviu?" && @e[:time_signature_label] == "4/4" && @e[:key_label] == "Dó maior")
    check(@e[:reference_label] == "Dó inicial em cada voz")
    check(%w[piano flute clarinet guitar organ].include?(@e[:instrument]))
    options = @e.fetch(:options)
    check(options.is_a?(Array) && options.size == 4)
    ids = options.map { |o| o[:id] }
    check(ids.all? { |id| id.is_a?(String) && /\A[0-9a-f]{24}\z/.match?(id) } && ids.uniq.size == 4)
    projections = options.each_with_index.map do |option, i|
      check(option[:label] == "Opção #{('A'.ord + i).chr}")
      validate_voices(option.fetch(:voices))
    end
    check(projections.uniq.size == 4)
    audio = @e.fetch(:audio_events)
    check(audio.is_a?(Array) && audio.size.between?(4,64))
    actual = audio.map do |event|
      check(event[:start_step].is_a?(Integer) && event[:duration_steps].is_a?(Integer))
      index = @octaves.each_index.find { |i| event[:voice_id] == "voice-#{i + 1}" }
      check(!index.nil?)
      midi = midi(event[:pitch], @octaves[index])
      expected = 440.0 * 2**((midi - 69) / 12.0)
      hz = event[:frequency]
      check(hz.is_a?(Numeric) && hz.finite? && (hz - expected).abs < 0.001)
      [event[:start_step], event[:duration_steps], midi]
    end.sort
    correct = projections.index(actual)
    check(!correct.nil? && ids[correct] == @e[:correct_option_id] && options[correct][:label] == @e[:correct_option_label])
    # Voice ownership is also exact, even though acoustic uniqueness ignores IDs.
    expected_events = options[correct][:voices].flat_map { |v| v[:events].map { |e| e.merge(voice_id: v[:id]) } }
    check(expected_events.sort_by { |e| [e[:voice_id], e[:start_step]] } == audio.map { |e| e.except(:frequency) }.sort_by { |e| [e[:voice_id], e[:start_step]] })
    check(@e[:signature] == ExerciseIntegrityValidator.digest(@e[:dictation_format], @e.except(:signature, :assignment_id, :attempt_token)))
    true
  rescue KeyError, TypeError, NoMethodError, IndexError, ArgumentError => error
    raise error if error.is_a?(ExerciseIntegrityValidator::Invalid)
    raise ExerciseIntegrityValidator::Invalid, "voiced_dictation_payload"
  end

  private

  def validate_voices(voices)
    check(voices.is_a?(Array) && voices.size == @octaves.size)
    melodic_lines = []
    voices.each_with_index.flat_map do |voice, i|
      check(voice[:id] == "voice-#{i+1}" && voice[:clef] == (@octaves[i] >= 4 ? "treble" : "bass"))
      events = voice.fetch(:events)
      limits = [[4,4],[6,8],[10,12],[12,16]].fetch(@level-1)
      check(events.is_a?(Array) && events.size.between?(*limits))
      cursor = 0
      previous = nil
      melodic_lines << events.map { |e| [e[:start_step], e[:duration_steps], e[:pitch].to_s[0]] }
      projection = events.map do |event|
        duration = event[:duration_steps]
        check(event[:start_step].is_a?(Integer) && event[:start_step] == cursor)
        check(duration.is_a?(Integer) && (@level == 1 ? [4] : (@level < 4 ? [2,4] : [1,2,4])).include?(duration))
        check((cursor % 4) + duration <= 4)
        sounding = midi(event[:pitch], @octaves[i])
        position = NATURAL.keys.index(event[:pitch][0])
        check(previous.nil? ? position.zero? : (position != previous && (position-previous).abs <= (@level <= 2 ? 2 : 3)))
        previous = position
        cursor += duration
        [event[:start_step], duration, sounding]
      end
      check(cursor == @bars * 16)
      check(events.any? { |e| e[:duration_steps] == 1 }) if @level == 4
      check(melodic_lines.uniq.size == melodic_lines.size)
      projection
    end.sort
  end

  def midi(value, octave)
    check(value.is_a?(String) && /\A[CDEFGAB]#{octave}\z/.match?(value))
    12 * (octave + 1) + NATURAL.fetch(value[0])
  end

  def check(condition)
    raise ExerciseIntegrityValidator::Invalid, "voiced_dictation_contract" unless condition
  end
end
