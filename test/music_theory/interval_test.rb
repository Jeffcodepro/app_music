require "minitest/autorun"
require_relative "../../app/models/music_theory/interval"

class MusicTheoryIntervalTest < Minitest::Test
  # Reference classifications are literal musical facts, not library output.
  REFERENCES = [
    ["C4", "E4", 3, 4, :major, :ascending, :ascending, "M3"],
    ["C4", "Eb4", 3, 3, :minor, :ascending, :ascending, "m3"],
    ["E4", "A3", 5, -7, :perfect, :descending, :descending, "P5"],
    ["C4", "F4", 4, 5, :perfect, :ascending, :ascending, "P4"],
    ["C4", "E#4", 3, 5, :augmented, :ascending, :ascending, "A3"],
    ["C4", "Gb4", 5, 6, :diminished, :ascending, :ascending, "d5"],
    ["C4", "F#4", 4, 6, :augmented, :ascending, :ascending, "A4"],
    ["C4", "Ebb4", 3, 2, :diminished, :ascending, :ascending, "d3"],
    ["C4", "Bbb4", 7, 9, :diminished, :ascending, :ascending, "d7"],
    ["G4", "Cb4", 5, -8, :augmented, :descending, :descending, "A5"],
    ["C4", "C4", 1, 0, :perfect, :stationary, :stationary, "P1"],
    ["C4", "C#4", 1, 1, :augmented, :stationary, :ascending, "A1"],
    ["C#4", "C4", 1, -1, :augmented, :stationary, :descending, "A1"],
    ["C#4", "Db4", 2, 0, :diminished, :ascending, :stationary, "d2"],
    ["Db4", "C#4", 2, 0, :diminished, :descending, :stationary, "d2"],
    ["B#3", "C4", 2, 0, :diminished, :ascending, :stationary, "d2"],
    ["C4", "C5", 8, 12, :perfect, :ascending, :ascending, "P8"],
    ["C4", "Db5", 9, 13, :minor, :ascending, :ascending, "m9"],
    ["C4", "D5", 9, 14, :major, :ascending, :ascending, "M9"],
    ["C4", "E5", 10, 16, :major, :ascending, :ascending, "M10"],
    ["C4", "F#5", 11, 18, :augmented, :ascending, :ascending, "A11"],
    ["C4", "G5", 12, 19, :perfect, :ascending, :ascending, "P12"],
    ["C4", "A5", 13, 21, :major, :ascending, :ascending, "M13"],
    ["C4", "Bbb5", 14, 21, :diminished, :ascending, :ascending, "d14"],
    ["C4", "C6", 15, 24, :perfect, :ascending, :ascending, "P15"]
  ].freeze

  def interval(first, last)
    MusicTheory::Interval.new(from: MusicTheory::Note.parse(first), to: MusicTheory::Note.parse(last))
  end

  def test_literal_simple_compound_chromatic_and_enharmonic_intervals
    REFERENCES.each do |first, last, number, chromatic, quality, written, sounding, shorthand|
      value = interval(first, last)
      assert_equal number, value.number, "#{first} -> #{last}"
      assert_equal chromatic, value.chromatic_steps
      assert_equal chromatic.abs, value.semitones
      assert_equal quality, value.quality
      assert_equal written, value.written_direction
      assert_equal sounding, value.sounding_direction
      assert_equal shorthand, value.shorthand
      assert_equal number > 8, value.compound?
    end
  end

  def test_diatonic_distance_is_signed_and_does_not_follow_frequency
    value = interval("C#4", "Db4")
    assert_equal 1, value.diatonic_steps
    assert_equal 0, value.chromatic_steps
    assert_equal :ascending, value.written_direction
    assert_equal :stationary, value.sounding_direction
    assert_equal(-4, interval("E4", "A3").diatonic_steps)
  end

  def test_same_semitone_distance_does_not_imply_same_interval
    assert_equal 5, interval("C4", "E#4").semitones
    assert_equal 5, interval("C4", "F4").semitones
    assert_equal 3, interval("C4", "E#4").number
    assert_equal 4, interval("C4", "F4").number
    refute_equal interval("C4", "E#4").quality, interval("C4", "F4").quality
  end

  def test_simple_reduction_preserves_octaves
    assert_equal 1, interval("C4", "C4").simple_number
    assert_equal 8, interval("C4", "C5").simple_number
    assert_equal 2, interval("C4", "D5").simple_number
    assert_equal 8, interval("C4", "C6").simple_number
    assert_equal "major third", interval("C4", "E4").name
    assert_equal "perfect fifteenth", interval("C4", "C6").name
  end

  def test_intervals_are_immutable_values_with_written_endpoints
    first, second = interval("C4", "E4"), interval("C4", "E4")
    assert first.frozen?
    assert first.from.frozen?
    assert_equal first, second
    assert_equal first.hash, second.hash
    assert_equal 1, { first => 1 }[second]
    refute_equal first, interval("C4", "Fb4")
    assert_raises(FrozenError) { first.instance_variable_set(:@number, 5) }
  end

  def test_unsupported_qualities_crossed_motion_and_size_are_explicit
    # Doubly augmented/diminished qualities and opposite written/sounding motion
    # are intentionally outside this first domain API.
    [["C4", "C##4"], ["C4", "F##4"], ["C##4", "Db4"], ["C4", "D6"]].each do |first, last|
      assert_raises(MusicTheory::Interval::Unsupported) { interval(first, last) }
    end
    assert_raises(ArgumentError) { MusicTheory::Interval.new(from: "C4", to: MusicTheory::Note.parse("E4")) }
  end

  def test_reversing_supported_intervals_preserves_quality_and_reverses_both_distances
    REFERENCES.each do |first, last, *_facts|
      forward, reverse = interval(first, last), interval(last, first)
      assert_equal forward.number, reverse.number
      assert_equal forward.quality, reverse.quality
      assert_equal(-forward.diatonic_steps, reverse.diatonic_steps)
      assert_equal(-forward.chromatic_steps, reverse.chromatic_steps)
    end
  end
end
