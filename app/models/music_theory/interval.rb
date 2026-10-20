require_relative "note"

module MusicTheory
  class Interval
    class Unsupported < ArgumentError; end

    NUMBERS = %w[unison second third fourth fifth sixth seventh octave ninth tenth eleventh twelfth thirteenth fourteenth fifteenth].map(&:freeze).freeze
    MAJOR_SEMITONES = [0, 2, 4, 5, 7, 9, 11].freeze
    SHORTHANDS = { perfect: "P", major: "M", minor: "m", augmented: "A", diminished: "d" }.transform_values(&:freeze).freeze

    attr_reader :from, :to, :diatonic_steps, :chromatic_steps, :number, :quality

    def initialize(from:, to:)
      raise ArgumentError, "interval endpoints must be MusicTheory::Note values" unless from.instance_of?(Note) && to.instance_of?(Note)

      @from, @to = from, to
      @diatonic_steps = to.diatonic_index - from.diatonic_index
      @chromatic_steps = to.midi - from.midi
      @number = diatonic_steps.abs + 1
      raise Unsupported, "interval number must be in 1..15" unless (1..15).cover?(number)
      if diatonic_steps * chromatic_steps < 0
        raise Unsupported, "opposite written and sounding motion is not supported"
      end

      @quality = classify_quality
      freeze
    end

    def semitones
      chromatic_steps.abs
    end

    def written_direction
      direction_for(diatonic_steps)
    end

    def sounding_direction
      direction_for(chromatic_steps)
    end

    def compound?
      number > 8
    end

    def simple_number
      number == 1 ? 1 : ((number - 2) % 7) + 2
    end

    def shorthand
      "#{SHORTHANDS.fetch(quality)}#{number}"
    end

    def name
      "#{quality} #{NUMBERS.fetch(number - 1)}"
    end

    def ==(other)
      other.instance_of?(self.class) && from == other.from && to == other.to
    end
    alias_method :eql?, :==

    def hash
      [self.class, from, to].hash
    end

    private

    def classify_quality
      steps = diatonic_steps.abs
      baseline = MAJOR_SEMITONES.fetch(steps % 7) + 12 * (steps / 7)
      delta = semitones - baseline
      perfect = [0, 3, 4].include?(steps % 7)
      qualities = perfect ? { 0 => :perfect, 1 => :augmented, -1 => :diminished } :
                            { 0 => :major, -1 => :minor, 1 => :augmented, -2 => :diminished }
      qualities.fetch(delta) { raise Unsupported, "multiple augmented/diminished qualities are not supported" }
    end

    def direction_for(steps)
      return :stationary if steps.zero?
      steps.positive? ? :ascending : :descending
    end
  end
end
