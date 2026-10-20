require "test_helper"

class RhythmIntegrityTest < ActiveSupport::TestCase
  test "parser rejects every unknown or empty token" do
    ["n4.INVALID.n4.n4.n4", "n4.n4.n4.n4.", ".n4.n4.n4.n4", "n4..n4.n4.n4", "", "n8.n8"].each do |signature|
      assert_raises(ArgumentError, signature) { RhythmExerciseGenerator.parse_pattern_signature(signature) }
      assert_nil RhythmExerciseGenerator.option_from_signature(signature)
    end
  end

  test "only complete measures are accepted" do
    assert RhythmExerciseGenerator.option_from_signature("n4.r2.n2.n4.r4")
    assert_nil RhythmExerciseGenerator.option_from_signature("n4.n4.n4.n2.n1")
    assert_nil RhythmExerciseGenerator.option_from_signature("n4.n4.n4.n4.n1")
  end

  test "split rests and note lengths do not distinguish percussive attacks" do
    first = "n4.n4.n4.r4"
    split = "n4.n4.n4.r2.r2"
    shortened = "n4.n4.n2.r2.r4"
    expected = RhythmExerciseGenerator.auditory_signature_for(first)
    assert_equal expected, RhythmExerciseGenerator.auditory_signature_for(split)
    assert_equal expected, RhythmExerciseGenerator.auditory_signature_for(shortened)
  end

  test "generated alternatives have distinct attack projections" do
    200.times do |seed|
      exercise = RhythmExerciseGenerator.new(random: Random.new(seed)).call
      projections = exercise[:options].map { |option| RhythmExerciseGenerator.auditory_signature_for(option[:id]) }
      assert_equal 4, projections.uniq.size, "seed #{seed}"
    end
  end

  test "generator fails closed when randomness cannot produce a valid candidate" do
    random = Object.new
    def random.rand(*) = 3
    assert_raises(RhythmExerciseGenerator::GenerationError) do
      RhythmExerciseGenerator.new(random:, activity_mode: "pulse").call
    end
  end
end
