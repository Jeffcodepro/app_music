# Versioned editorial content presets; independent from User proficiency/plans.
class ListeningDifficulty
  SIMPLE_INTERVALS = %w[minor_second major_second minor_third major_third perfect_fourth perfect_fifth minor_sixth major_sixth minor_seventh major_seventh perfect_octave].freeze
  def self.validate_level!(level)
    raise ArgumentError, "invalid difficulty level" unless level.is_a?(Integer) && (1..4).cover?(level)
    level
  end
  def self.intervals(level)
    validate_level!(level)
    return %w[major_second major_third perfect_fourth perfect_fifth perfect_octave] if level == 1
    return SIMPLE_INTERVALS if level == 2
    return SIMPLE_INTERVALS + %w[minor_ninth major_ninth minor_tenth major_tenth perfect_eleventh perfect_twelfth] if level == 3
    PerceptionIntervalExerciseGenerator::INTERVAL_LIBRARY.map { |i| i[:id] }
  end
  def self.harmony_modes(level)
    validate_level!(level)
    %w[quality scale_degree] + (level >= 2 ? ["harmonic_function"] : []) + (level >= 3 ? ["progression"] : [])
  end
  def self.harmony_keys(level)
    validate_level!(level)
    %w[c_major] + (level >= 2 ? %w[g_major f_major] : []) + (level >= 3 ? %w[d_major bb_major] : []) + (level == 4 ? %w[a_major eb_major] : [])
  end
  def self.harmony_structures(level) = validate_level!(level) < 3 ? ["triad"] : %w[triad tetrad]
  def self.harmony_degrees(level) = validate_level!(level) == 1 ? [1,4,5,6] : (1..7).to_a
end
