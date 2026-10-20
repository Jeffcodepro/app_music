# Independent arithmetic and literal format contract; does not trust generator tables.
class MelodicDictationIntegrityValidator
  def self.validate!(exercise)
    new(exercise).validate!
  end

  def initialize(exercise)
    @e = exercise.to_h.deep_symbolize_keys
  end

  def validate!
    check(@e.values_at(:question_mode, :question_type) == ["melodic_dictation"] * 2)
    check(@e[:question] == "Qual partitura você ouviu?")
    check(@e[:voice_count] == 1 && @e[:duration_steps] == 4 && @e[:time_signature_label] == "4/4")
    check(@e[:key_label] == "Dó maior" && @e[:reference_pitch] == "C4")
    check(@e[:tempo_bpm] == 80)
    check(PerceptionIntervalExerciseGenerator.instruments.any? { |i| i[:id] == @e[:instrument] })
    options = @e.fetch(:options)
    check(options.is_a?(Array) && options.size == 4)
    ids = options.map { |o| o.fetch(:id) }
    check(ids.all? { |id| id.is_a?(String) && id.match?(/\A[0-9a-f]{24}\z/) } && ids.uniq.size == 4)
    sequences = options.each_with_index.map do |o, i|
      check(o[:label] == "Opção #{('A'.ord + i).chr}")
      notes(o[:pitches])
    end
    check(sequences.uniq.size == 4)
    audio = @e.fetch(:audio_sequence)
    check(audio.is_a?(Array) && audio.size == 4)
    audio_pitches = audio.map do |event|
      check(event[:pitches].is_a?(Array) && event[:pitches].size == 1)
      check(event[:frequencies].is_a?(Array) && event[:frequencies].size == 1)
      event[:pitches].first
    end
    sounding = notes(audio_pitches)
    audio.each_with_index do |event, i|
      expected = 440.0 * 2.0**((sounding[i] - 69) / 12.0)
      frequency = event[:frequencies].first
      check(frequency.is_a?(Numeric) && frequency.finite? && (frequency - expected).abs < 0.001)
    end
    index = sequences.index(sounding)
    check(!index.nil? && options[index][:id] == @e[:correct_option_id] && options[index][:label] == @e[:correct_option_label])
    check(@e[:signature] == Digest::SHA256.hexdigest(audio_pitches.join("|")))
    true
  rescue KeyError, TypeError, NoMethodError, ArgumentError => e
    raise e if e.is_a?(ExerciseIntegrityValidator::Invalid)
    raise ExerciseIntegrityValidator::Invalid, "melodic_dictation_payload"
  end

  private

  def notes(values)
    check(values.is_a?(Array) && values.size == 4 && values.first == "C4")
    values.map do |value|
      check(value.is_a?(String) && value.match?(/\A(?:[CDEFGAB]4|C5)\z/))
      # Literal C-major positions, independent from canonical/generator frequency helpers.
      { "C4" => 60, "D4" => 62, "E4" => 64, "F4" => 65, "G4" => 67, "A4" => 69, "B4" => 71, "C5" => 72 }.fetch(value)
    end
  end

  def check(condition)
    raise ExerciseIntegrityValidator::Invalid, "melodic_dictation_contract" unless condition
  end
end
