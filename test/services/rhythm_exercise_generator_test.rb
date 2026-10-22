require "test_helper"

class RhythmExerciseGeneratorTest < ActiveSupport::TestCase
  test "builds four unique rhythmic options with a valid correct answer" do
    exercise = RhythmExerciseGenerator.new(random: Random.new(1234), activity_mode: "subdivision").call

    assert_equal 4, exercise[:options].size
    assert_equal 4, exercise[:options].pluck(:id).uniq.size
    assert_includes exercise[:options].pluck(:id), exercise[:correct_option_id]
    assert_equal "subdivision", exercise[:activity_mode]
    assert_operator exercise[:tempo_bpm], :>, 0
    assert_equal 4, exercise[:count_in_beats]
  end

  test "syncopation is unavailable until sustained metric displacement can be validated" do
    refute_includes RhythmExerciseGenerator.activity_mode_ids, "syncopation"
    assert_raises(RhythmExerciseGenerator::GenerationError) do
      RhythmExerciseGenerator.new(activity_mode: "syncopation").call
    end
  end

  test "mixed mode avoids immediately repeating recent activity modes when alternatives exist" do
    exercise = RhythmExerciseGenerator.new(
      random: Random.new(2026),
      activity_mode: "mixed",
      recent_exercises: [
        { activity_mode: "pulse", signature: "n4.n4.n4.r4" },
        { activity_mode: "subdivision", signature: "n2.n2.n1.n1.n2.n4.n2.r2" }
      ]
    ).call

    refute_includes %w[pulse subdivision], exercise[:activity_mode]
  end
end
