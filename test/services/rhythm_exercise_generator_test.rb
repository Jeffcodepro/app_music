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

  test "syncopation mode generates offbeat starts when possible" do
    exercise = RhythmExerciseGenerator.new(random: Random.new(88), activity_mode: "syncopation").call
    tokens = RhythmExerciseGenerator.parse_pattern_signature(exercise[:correct_option_id])
    cursor = 0
    beat_starts_with_rest = 0

    tokens.each do |token|
      beat_starts_with_rest += 1 if (cursor % RhythmExerciseGenerator::STEPS_PER_BEAT).zero? && token[:kind] == "rest"
      cursor += token[:duration_steps]
    end

    assert_equal "syncopation", exercise[:activity_mode]
    assert_equal 16, tokens.sum { |token| token[:duration_steps] }
    assert_operator beat_starts_with_rest, :>=, 2
    assert_includes exercise[:question].downcase, "ataques fora do tempo forte"
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
