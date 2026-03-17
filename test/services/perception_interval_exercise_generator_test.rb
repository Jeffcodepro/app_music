require "test_helper"

class PerceptionIntervalExerciseGeneratorTest < ActiveSupport::TestCase
  test "builds four unique options with a valid correct answer" do
    exercise = PerceptionIntervalExerciseGenerator.new(random: Random.new(1234)).call

    assert_equal 4, exercise[:options].size
    assert_equal 4, exercise[:options].pluck(:id).uniq.size
    assert_includes exercise[:options].pluck(:id), exercise[:correct_option_id]
    assert_operator exercise[:reference_frequency], :>, 0
    assert_operator exercise[:target_frequency], :>, 0
  end

  test "keeps descending mode fixed when requested" do
    exercise = PerceptionIntervalExerciseGenerator.new(
      random: Random.new(999),
      direction_mode: "descending",
      instrument: "guitar"
    ).call

    assert_equal "descending", exercise[:direction]
    assert_equal "Decrescente", exercise[:direction_label]
    assert_equal "guitar", exercise[:instrument]
    assert_equal "Violão", exercise[:instrument_label]
  end

  test "generates pitches that match the stored interval label" do
    exercise = PerceptionIntervalExerciseGenerator.new(random: Random.new(4567)).call
    reference_pitch = HeadMusic::Rudiment::Pitch.get(exercise[:reference_pitch])
    target_pitch = HeadMusic::Rudiment::Pitch.get(exercise[:target_pitch])
    interval = HeadMusic::Analysis::DiatonicInterval.new(reference_pitch, target_pitch)

    correct_option = exercise[:options].find { |option| option[:id] == exercise[:correct_option_id] }

    assert_equal exercise[:correct_interval_name], interval.name
    assert_equal correct_option[:label], exercise[:correct_option_label]
  end

  test "mixed mode only alternates between crescente and decrescente" do
    exercise = PerceptionIntervalExerciseGenerator.new(random: Random.new(2026), direction_mode: "mixed").call

    assert_includes %w[ascending descending], exercise[:direction]
    assert_equal "Misto", exercise[:direction_mode_label]
  end

  test "supports all configured instruments including organ and guitar" do
    assert_includes PerceptionIntervalExerciseGenerator.instrument_ids, "organ"
    assert_includes PerceptionIntervalExerciseGenerator.instrument_ids, "guitar"
  end

  test "avoids immediately repeating recent interval ids when possible" do
    exercise = PerceptionIntervalExerciseGenerator.new(
      random: Random.new(88),
      recent_exercises: [
        { interval_id: "major_third", signature: "major_third|ascending|C4|E4" },
        { interval_id: "perfect_fifth", signature: "perfect_fifth|ascending|D4|A4" }
      ]
    ).call

    refute_includes %w[major_third perfect_fifth], exercise[:correct_option_id]
  end

  test "localizes pitch names to brazilian notation with octave" do
    assert_equal "Dó 4", PerceptionIntervalExerciseGenerator.localize_pitch_name("C4")
    assert_equal "Fá sustenido 4", PerceptionIntervalExerciseGenerator.localize_pitch_name("F#4")
    assert_equal "Si bemol 3", PerceptionIntervalExerciseGenerator.localize_pitch_name("Bb3")
  end
end
