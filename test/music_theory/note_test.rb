require "minitest/autorun"
require_relative "../../app/models/music_theory/note"

class MusicTheoryNoteTest < Minitest::Test
  # Literal reference values, not obtained from HeadMusic or the implementation.
  REFERENCES = [
    ["C4", "C", 0, 4, 60, 261.625565301],
    ["D4", "D", 0, 4, 62, 293.664767917],
    ["E4", "E", 0, 4, 64, 329.627556913],
    ["F4", "F", 0, 4, 65, 349.228231433],
    ["G4", "G", 0, 4, 67, 391.995435982],
    ["A4", "A", 0, 4, 69, 440.0],
    ["B4", "B", 0, 4, 71, 493.883301256],
    ["F#4", "F", 1, 4, 66, 369.994422712],
    ["Gb4", "G", -1, 4, 66, 369.994422712],
    ["E#4", "E", 1, 4, 65, 349.228231433],
    ["Db4", "D", -1, 4, 61, 277.182630977],
    ["C##4", "C", 2, 4, 62, 293.664767917],
    ["Dbb4", "D", -2, 4, 60, 261.625565301],
    ["B#3", "B", 1, 3, 60, 261.625565301],
    ["Cb4", "C", -1, 4, 59, 246.941650628],
    ["B##3", "B", 2, 3, 61, 277.182630977],
    ["Cbb4", "C", -2, 4, 58, 233.081880759],
    ["C5", "C", 0, 5, 72, 523.251130601],
    ["C-1", "C", 0, -1, 0, 8.175798916],
    ["B#-2", "B", 1, -2, 0, 8.175798916],
    ["G9", "G", 0, 9, 127, 12543.853951416]
  ].freeze

  def test_literal_natural_altered_and_octave_boundary_references
    REFERENCES.each do |name, step, alter, octave, midi, frequency|
      note = MusicTheory::Note.parse(name)
      assert_equal({ step:, alter:, octave: }, note.to_h, name)
      assert_equal midi, note.midi, name
      assert_in_delta frequency, note.frequency, 0.00000001, name
      assert_equal name, note.to_s
    end
  end

  def test_ascii_and_unicode_spellings_preserve_written_identity
    { "F♯4" => "F#4", "G♭4" => "Gb4", "C𝄪4" => "C##4", "D𝄫4" => "Dbb4", "F♮4" => "F4" }.each do |unicode, ascii|
      assert MusicTheory::Note.parse(unicode).same_spelling?(MusicTheory::Note.parse(ascii))
    end
    assert_equal "F♯4", MusicTheory::Note.parse("F#4").spelling
    assert_equal "C𝄪4", MusicTheory::Note.parse("C##4").spelling
  end

  def test_enharmonic_equality_is_distinct_from_spelling_and_octave_identity
    [["F#4", "Gb4"], ["E#4", "F4"], ["C#4", "Db4"], ["B#3", "C4"]].each do |first, last|
      left, right = [first, last].map { |name| MusicTheory::Note.parse(name) }
      assert left.same_pitch?(right)
      refute left.same_spelling?(right)
      refute_equal left, right
    end
    refute MusicTheory::Note.parse("C4").same_pitch?(MusicTheory::Note.parse("C5"))
    refute MusicTheory::Note.parse("F#4").same_pitch?(MusicTheory::Note.parse("E#4"))
    refute MusicTheory::Note.parse("C4").same_pitch?("C4")
  end

  def test_value_equality_and_hash_keys_use_spelling
    first = MusicTheory::Note.new(step: "F", alter: 1, octave: 4)
    same = MusicTheory::Note.parse("F♯4")
    assert_equal first, same
    assert first.eql?(same)
    assert_equal first.hash, same.hash
    assert_equal 1, { first => 1 }[same]
  end

  def test_notes_do_not_freeze_or_retain_mutable_caller_state
    step = +"F"
    note = MusicTheory::Note.new(step:, alter: 1, octave: 4)
    step.replace("C")
    assert_equal "F", note.step
    assert note.frozen?
    assert note.step.frozen?
    assert_raises(FrozenError) { note.step.replace("G") }
    assert_raises(FrozenError) { note.instance_variable_set(:@alter, -1) }
    note.to_h[:alter] = -1
    assert_equal 1, note.alter
  end

  def test_changing_an_alteration_returns_another_value
    natural = MusicTheory::Note.parse("F4")
    assert_equal "F#4", natural.with_alter(1).to_s
    assert_equal "F4", natural.to_s
    assert_equal 0, natural.alter
  end

  def test_explicit_reference_tuning_is_validated_and_never_changes_note_identity
    note = MusicTheory::Note.parse("A4")
    assert_equal 442.0, note.frequency(a4: 442)
    assert_equal 220.0, MusicTheory::Note.parse("A3").frequency(a4: 440)
    assert_equal 20_000.0, note.frequency(a4: 20_000)
    assert_raises(ArgumentError) { note.frequency(a4: 20_000.1) }
    assert_equal 69, note.midi
    [nil, "440", true, 0, -440, Float::NAN, Float::INFINITY, Complex(440, 1), 10**1000].each do |value|
      assert_raises(ArgumentError) { note.frequency(a4: value) }
    end
    assert_raises(ArgumentError) { MusicTheory::Note.parse("C-1").frequency(a4: Float::MIN * Float::EPSILON) }
    assert_raises(ArgumentError) { MusicTheory::Note.parse("G9").frequency(a4: 1000) }
  end

  def test_invalid_constructor_fields_and_out_of_range_midi_are_explicit
    [
      { step: "H", alter: 0, octave: 4 }, { step: :C, alter: 0, octave: 4 },
      { step: "c", alter: 0, octave: 4 }, { step: "C", alter: 0.5, octave: 4 },
      { step: "C", alter: 3, octave: 4 }, { step: "C", alter: -3, octave: 4 },
      { step: "C", alter: nil, octave: 4 }, { step: "C", alter: 0, octave: "4" },
      { step: "C", alter: 0, octave: 4.0 }, { step: "C", alter: 0, octave: -2 },
      { step: "G", alter: 1, octave: 9 }, { step: "B", alter: 0, octave: 100 }
    ].each { |fields| assert_raises(ArgumentError) { MusicTheory::Note.new(**fields) } }
  end

  def test_parser_rejects_partial_or_unsupported_notation
    [nil, {}, :C4, "", "C", "C4junk", " C4", "C4\n", "c4", "H4", "C###4", "Cb#4", "C♯♭4", "C4.0", "C+4"].each do |value|
      assert_raises(ArgumentError) { MusicTheory::Note.parse(value) }
    end
  end

  def test_generated_written_notes_round_trip_and_octaves_double_frequency
    # Exhaustive supported spellings, deterministic and independent of HeadMusic.
    %w[C D E F G A B].product((-2..2).to_a, (0..8).to_a).each do |step, alter, octave|
      note = MusicTheory::Note.new(step:, alter:, octave:)
      assert_equal note, MusicTheory::Note.parse(note.to_s)
      assert_equal note, MusicTheory::Note.parse(note.spelling)
      assert note.frequency.finite?
      next unless note.midi + 12 <= 127
      upper = MusicTheory::Note.new(step:, alter:, octave: octave + 1)
      assert_equal 12, upper.midi - note.midi
      assert_equal 7, upper.diatonic_index - note.diatonic_index
      assert_in_delta note.frequency * 2, upper.frequency, 0.00000001
    end
  end
end
