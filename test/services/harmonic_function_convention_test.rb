require "test_helper"
require "yaml"
require "minitest/mock"

class HarmonicFunctionConventionTest < ActiveSupport::TestCase
  test "literal objective fixtures and explicit legacy policy agree with validation" do
    references = YAML.safe_load_file(Rails.root.join("test/support/major_harmony_reference.yml"))
    references.each do |reference|
      generator = HarmonyExerciseGenerator.new(chord_structure: "triad")
      key = HarmonyExerciseGenerator.key_definition("c_major")
      chord = generator.send(:chord_for_degree, key_definition: key, degree: reference.fetch("degree"))
      assert_equal reference.fetch("pitches"), chord[:pitches]
      function = reference.fetch("function")
      assert_equal function, HarmonicFunctionConvention.function(reference.fetch("degree"), version: "major-functions-legacy-v1")
      exercise = generator.send(:build_common_exercise, question_type: "harmonic_function", key_definition: key, chord:,
                                correct_option_id: function, correct_option_label: HarmonyExerciseGenerator.function_definition(function)[:label],
                                signature: "reference", options: HarmonyExerciseGenerator::FUNCTION_OPTIONS)
      exercise[:chord_structure] = "triad"
      assert ExerciseIntegrityValidator.validate!("harmonia", exercise)
      assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("harmonia", exercise.merge(function_convention_id: "unknown-v99")) }
      mutated = exercise.deep_dup
      mutated[:audio_sequence].last[:pitches][0] = "C1"
      assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("harmonia", mutated) }
    end
  end

  test "a mistaken generator classification is not an authority for validation" do
    generator = HarmonyExerciseGenerator.new(random: Random.new(0), question_mode: "harmonic_function")
    generator.stub(:sampled_degree, 1) do
      generator.stub(:function_for_degree, "dominant") do
        assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("harmonia", generator.call) }
      end
    end
    exercise = HarmonyExerciseGenerator.new(random: Random.new(0), question_mode: "harmonic_function").call
    wrong = (HarmonyExerciseGenerator::FUNCTION_OPTIONS.pluck(:id) - [exercise[:correct_option_id]]).first
    label = HarmonyExerciseGenerator.function_definition(wrong)[:label]
    mutated = exercise.merge(correct_option_id: wrong, correct_option_label: label, chord_function_id: wrong, chord_function_label: label)
    assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("harmonia", mutated) }
  end
end
