module MusicTheory
  # A written pitch in 12-tone equal temperament. No staff/key signature context
  # is inferred here: alter is the resulting chromatic alteration, not a glyph.
  class Note
    STEPS = %w[C D E F G A B].map(&:freeze).freeze
    NATURAL_SEMITONES = [0, 2, 4, 5, 7, 9, 11].freeze
    ASCII_ALTERATIONS = { -2 => "bb", -1 => "b", 0 => "", 1 => "#", 2 => "##" }.transform_values(&:freeze).freeze
    SYMBOLS = { -2 => "𝄫", -1 => "♭", 0 => "", 1 => "♯", 2 => "𝄪" }.transform_values(&:freeze).freeze
    PARSED_ALTERATIONS = { "bb" => -2, "b" => -1, "" => 0, "#" => 1, "##" => 2,
                          "𝄫" => -2, "♭" => -1, "♮" => 0, "♯" => 1, "𝄪" => 2 }.freeze
    MIDI_RANGE = (0..127).freeze
    DEFAULT_A4 = 440.0
    MAX_FREQUENCY = 20_000.0

    attr_reader :step, :alter, :octave, :midi, :diatonic_index

    def initialize(step:, octave:, alter: 0)
      raise ArgumentError, "step must be an uppercase A-G string" unless step.is_a?(String) && STEPS.include?(step)
      raise ArgumentError, "alter must be an integer from -2 to 2" unless alter.is_a?(Integer) && (-2..2).cover?(alter)
      raise ArgumentError, "octave must be an integer" unless octave.is_a?(Integer)

      index = STEPS.index(step)
      @midi = 12 * (octave + 1) + NATURAL_SEMITONES.fetch(index) + alter
      raise ArgumentError, "resulting MIDI pitch must be in 0..127" unless MIDI_RANGE.cover?(@midi)

      @step, @alter, @octave = step.dup.freeze, alter, octave
      @diatonic_index = octave * 7 + index
      freeze
    end

    def self.parse(value)
      match = value.is_a?(String) && /\A([A-G])(bb|##|b|#|𝄫|♭|♮|♯|𝄪)?(-?\d+)\z/.match(value)
      raise ArgumentError, "expected a complete written pitch with octave" unless match

      new(step: match[1], alter: PARSED_ALTERATIONS.fetch(match[2].to_s), octave: Integer(match[3], 10))
    end

    def with_alter(alter)
      self.class.new(step:, alter:, octave:)
    end

    def to_h
      { step:, alter:, octave: }
    end

    def to_s
      "#{step}#{ASCII_ALTERATIONS.fetch(alter)}#{octave}"
    end

    # Unicode spelling keeps the legacy HeadMusic pitch strings at the boundary.
    def spelling
      "#{step}#{SYMBOLS.fetch(alter)}#{octave}"
    end

    def frequency(a4: DEFAULT_A4)
      unless a4.is_a?(Numeric) && a4.real? && a4.to_f.finite? && a4.positive?
        raise ArgumentError, "A4 reference must be a positive finite real number"
      end
      hz = a4.to_f * 2.0**((midi - 69) / 12.0)
      unless hz.finite? && hz.positive? && hz <= MAX_FREQUENCY
        raise ArgumentError, "resulting frequency must be finite and in (0, 20000] Hz"
      end
      hz
    end

    def same_spelling?(other)
      other.instance_of?(self.class) && step == other.step && alter == other.alter && octave == other.octave
    end

    def same_pitch?(other)
      other.instance_of?(self.class) && midi == other.midi
    end

    alias_method :==, :same_spelling?
    alias_method :eql?, :same_spelling?

    def hash
      [self.class, step, alter, octave].hash
    end
  end
end
