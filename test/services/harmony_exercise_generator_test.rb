require "test_helper"

class HarmonyExerciseGeneratorTest < ActiveSupport::TestCase
  test "builds four unique options and an audio payload for triads" do
    exercise = HarmonyExerciseGenerator.new(random: Random.new(1234), question_mode: "quality", chord_structure: "triad").call

    assert_equal 4, exercise[:options].size
    assert_equal 4, exercise[:options].pluck(:id).uniq.size
    assert_includes exercise[:options].pluck(:id), exercise[:correct_option_id]
    assert_equal "triad", exercise[:chord_structure]
    assert_equal 1, exercise[:audio_sequence].size
    assert_equal 3, exercise[:audio_sequence].first[:pitches].size
    assert_equal 3, exercise[:audio_sequence].first[:frequencies].size
  end

  test "builds tetrad exercises with four-note audio" do
    exercise = HarmonyExerciseGenerator.new(random: Random.new(99), question_mode: "quality", chord_structure: "tetrad").call

    assert_equal "tetrad", exercise[:chord_structure]
    assert_equal "Tétrades", exercise[:question_type_label]
    assert_equal 4, exercise[:audio_sequence].first[:pitches].size
    assert_includes HarmonyExerciseGenerator.quality_options_for("tetrad").pluck(:id), exercise[:correct_option_id]
  end

  test "builds scale degree exercises with tonal reference before the target chord" do
    exercise = HarmonyExerciseGenerator.new(random: Random.new(77), question_mode: "scale_degree", chord_structure: "triad").call

    assert_equal "scale_degree", exercise[:question_type]
    assert_equal 2, exercise[:audio_sequence].size
    assert_equal "I", exercise[:audio_sequence].first[:label]
    assert_includes exercise[:question], "tônica da tonalidade"
    assert_includes exercise[:prompt_value], "Primeiro I"
    assert_equal "Referência", exercise[:context_items].last[:label]
  end

  test "builds harmonic function exercises with tonal reference before the target chord" do
    exercise = HarmonyExerciseGenerator.new(random: Random.new(14), question_mode: "harmonic_function", chord_structure: "triad").call

    assert_equal "harmonic_function", exercise[:question_type]
    assert_equal 2, exercise[:audio_sequence].size
    assert_equal "I", exercise[:audio_sequence].first[:label]
    assert_includes exercise[:question], "tônica da tonalidade"
    assert_includes exercise[:prompt_value], "Primeiro I"
    assert_equal "Referência", exercise[:context_items].last[:label]
  end

  test "builds progression exercises with multiple audio steps" do
    exercise = HarmonyExerciseGenerator.new(random: Random.new(2026), question_mode: "progression", chord_structure: "tetrad").call

    assert_equal "progression", exercise[:question_type]
    assert_operator exercise[:audio_sequence].size, :>=, 2
    assert_equal 4, exercise[:audio_sequence].first[:pitches].size
    assert exercise[:question].include?("posição")
    assert_includes exercise[:options].pluck(:label), exercise[:correct_option_label]
    assert exercise[:progression_steps].any? { |step| step[:focus] }
  end

  test "localizes note spellings to brazilian notation" do
    assert_equal "Fá sustenido", HarmonyExerciseGenerator.localize_spelling("F#")
    assert_equal "Si bemol", HarmonyExerciseGenerator.localize_spelling("B♭")
  end
end
