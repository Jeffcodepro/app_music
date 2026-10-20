require "digest"

# First dictation format: one voice, four quarter notes, common C4 reference.
# Content bands/meters beyond this format await the curriculum proposal approval.
class MelodicDictationExerciseGenerator
  QUESTION = "Qual partitura você ouviu?".freeze
  SCALE = %w[C4 D4 E4 F4 G4 A4 B4 C5].freeze

  def initialize(instrument: "piano", random: Random.new, recent_exercises: [])
    @instrument = PerceptionIntervalExerciseGenerator.instrument_definition(instrument)[:id]
    @random = random
    @recent = recent_exercises.map { |e| e[:signature] || e["signature"] }
  end

  def call
    pitches = nil
    20.times do
      indices = [0]
      3.times { indices << [-2, -1, 1, 2].map { |step| indices.last + step }.select { |index| (0..7).cover?(index) }.sample(random: @random) }
      pitches = indices.map { |i| SCALE.fetch(i) }
      break unless @recent.include?(Digest::SHA256.hexdigest(pitches.join("|")))
    end
    candidates = [pitches]
    until candidates.size == 4
      candidate = pitches.dup
      position = @random.rand(1..3)
      candidate[position] = SCALE.sample(random: @random)
      candidates << candidate unless candidates.include?(candidate)
    end
    options = candidates.shuffle(random: @random).each_with_index.map do |notes, i|
      { id: @random.bytes(12).unpack1("H*"), label: "Opção #{('A'.ord + i).chr}", pitches: notes }
    end
    correct = options.find { |o| o[:pitches] == pitches }
    {
      question_mode: "melodic_dictation", question_type: "melodic_dictation", question: QUESTION,
      instrument: @instrument, voice_count: 1, time_signature_label: "4/4", tempo_bpm: 80,
      duration_steps: 4, key_label: "Dó maior", reference_pitch: "C4",
      options: options, correct_option_id: correct[:id], correct_option_label: correct[:label],
      audio_sequence: pitches.map { |p| { pitches: [p], frequencies: [MusicTheory::Note.parse(p).frequency] } },
      signature: Digest::SHA256.hexdigest(pitches.join("|"))
    }
  end
end
