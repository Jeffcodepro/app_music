# Conservative concert-pitch training windows, not a claim about every model's
# extreme range. Stored exercise pitches always match the audio (no JS shift).
class ExerciseInstrumentRegister
  RANGES = { "piano" => (21..108), "flute" => (60..96), "clarinet" => (52..91), "guitar" => (40..83), "organ" => (24..108) }.freeze
  def self.range(instrument) = RANGES.fetch(instrument)
  def self.chord_offset(notes, instrument)
    window = range(instrument)
    [0,12,-12,24,-24].find { |offset| notes.all? { |note| window.cover?(note.midi + offset) } } || raise(ArgumentError, "chord exceeds instrument register")
  end
end
