# Explicit timed, separate melodic lines. The four-quarter legacy format stays intact.
class VoicedDictationExerciseGenerator
  FORMAT = "voices-v2".freeze
  def self.signature(e) = ExerciseIntegrityValidator.digest(e.fetch(:dictation_format), e.except(:signature, :assignment_id, :attempt_token))

  def initialize(level:, instrument: "piano", random: Random.new, recent_exercises: [])
    @level = ListeningDifficulty.validate_level!(level)
    raise ArgumentError, "unknown instrument" unless PerceptionIntervalExerciseGenerator.instrument_definition(instrument)
    raise ArgumentError, "advanced dictation requires piano" if @level == 4 && instrument != "piano"
    @instrument, @random = instrument, random
  end

  def call
    count = @level < 3 ? 1 : (@level == 3 ? 2 : @random.rand(3..4))
    @octaves = { 1 => [4], 2 => %w[flute clarinet].include?(@instrument) ? [5,4] : [4,3], 3 => [5,4,3], 4 => [5,4,3,2] }.fetch(count)
    @bars = @level < 3 ? 1 : 2
    correct_voices = build_voices
    candidates = [correct_voices]
    200.times do
      break if candidates.size == 4
      candidate = correct_voices.deep_dup
      index = @random.rand(count)
      candidate[index] = build_voice(index)
      next unless independent?(candidate)
      next if candidates.any? { |other| projection(other) == projection(candidate) }
      candidates << candidate
    end
    raise RhythmExerciseGenerator::GenerationError, "No four distinct melodic choices" unless candidates.size == 4
    options = candidates.shuffle(random: @random).each_with_index.map do |voices, i|
      { id: @random.bytes(12).unpack1("H*"), label: "Opção #{('A'.ord + i).chr}", voices: }
    end
    correct = options.find { |o| o[:voices] == correct_voices }
    audio = correct_voices.flat_map do |voice|
      voice[:events].map { |event| event.merge(voice_id: voice[:id], frequency: MusicTheory::Note.parse(event[:pitch]).frequency) }
    end.sort_by { |e| [e[:start_step], e[:frequency]] }
    e = { dictation_format: FORMAT, level: @level, question_mode: "melodic_dictation", question_type: "melodic_dictation",
      question: "Qual partitura você ouviu?", instrument: @instrument, voice_count: count,
      time_signature_label: "4/4", tempo_bpm: 80, bpm_unit_steps: 4, measure_count: @bars, total_steps: @bars * 16,
      key_label: "Dó maior", reference_label: "Dó inicial em cada voz", audio_events: audio,
      options:, correct_option_id: correct[:id], correct_option_label: correct[:label] }
    e[:signature] = self.class.signature(e)
    e
  end

  private

  def rhythm
    beats = Array.new(@bars * 4) { [4] }
    if @level == 2 || @level == 3
      (0...beats.size).to_a.sample(@random.rand(2..4), random: @random).each { |i| beats[i] = [2,2] }
    elsif @level == 4
      extra = @random.rand(4..8)
      fine = @random.rand(beats.size)
      beats[fine] = [[2,1,1], [1,1,2], [1,1,1,1]].sample(random: @random)
      remaining = extra - (beats[fine].size - 1)
      ((0...beats.size).to_a - [fine]).sample(remaining, random: @random).each { |i| beats[i] = [2,2] }
    end
    beats.flatten
  end

  def build_voice(index)
    octave = @octaves.fetch(index)
    step = 0
    cursor = 0
    events = rhythm.each_with_index.map do |duration, i|
      if i.positive?
        limit = @level <= 2 ? 2 : 3
        step = ((0..6).to_a - [step]).select { |n| (n - step).abs <= limit }.sample(random: @random)
      end
      e = { pitch: "#{%w[C D E F G A B].fetch(step)}#{octave}", start_step: cursor, duration_steps: duration }
      cursor += duration
      e
    end
    { id: "voice-#{index + 1}", clef: octave >= 4 ? "treble" : "bass", events: }
  end

  def build_voices
    40.times do
      voices = @octaves.each_index.map { |i| build_voice(i) }
      return voices if independent?(voices)
    end
    raise RhythmExerciseGenerator::GenerationError, "Independent melodic lines unavailable"
  end

  def independent?(voices)
    normalized = voices.map { |v| v[:events].map { |e| [e[:start_step], e[:duration_steps], e[:pitch][0]] } }
    normalized.uniq.size == voices.size
  end

  def projection(voices)
    voices.flat_map { |v| v[:events].map { |e| [e[:start_step], e[:duration_steps], MusicTheory::Note.parse(e[:pitch]).midi] } }.sort
  end
end
