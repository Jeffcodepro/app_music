require "test_helper"
require "minitest/mock"

class PerceptionReferenceMatrixTest < ActiveSupport::TestCase
  # Literal spellings/distances from C4, independent of generator transposition.
  REFERENCES = [
    ["minor_second", "Db4", 1], ["major_second", "D4", 2],
    ["minor_third", "Eb4", 3], ["major_third", "E4", 4],
    ["perfect_fourth", "F4", 5], ["perfect_fifth", "G4", 7],
    ["minor_sixth", "Ab4", 8], ["major_sixth", "A4", 9],
    ["minor_seventh", "Bb4", 10], ["major_seventh", "B4", 11],
    ["perfect_octave", "C5", 12], ["minor_ninth", "Db5", 13],
    ["major_ninth", "D5", 14], ["minor_tenth", "Eb5", 15],
    ["major_tenth", "E5", 16], ["perfect_eleventh", "F5", 17],
    ["perfect_twelfth", "G5", 19], ["minor_thirteenth", "Ab5", 20],
    ["major_thirteenth", "A5", 21], ["minor_fourteenth", "Bb5", 22],
    ["major_fourteenth", "B5", 23], ["perfect_fifteenth", "C6", 24]
  ].freeze

  test "every current interval has one independently expected answer in both directions after persistence" do
    user = User.create!(email: "reference-matrix@example.test", password: "password123", full_name: "Referência", plan: "Pulso")
    assert_equal REFERENCES.map(&:first).sort, PerceptionIntervalExerciseGenerator::INTERVAL_LIBRARY.map { |i| i[:id] }.sort
    REFERENCES.each_with_index do |(id, high, semitones), seed|
      %w[ascending descending].each do |direction|
        first, last = direction == "ascending" ? ["C4", high] : [high, "C4"]
        generator = PerceptionIntervalExerciseGenerator.new(random: Random.new(seed), direction_mode: direction)
        definition = PerceptionIntervalExerciseGenerator::INTERVAL_LIBRARY.find { |i| i[:id] == id }
        generator.stub(:sampled_interval_definition, definition) do
          generator.stub(:sampled_reference_pitch, MusicTheory::Note.parse(first)) do
            exercise = generator.call
            assert_equal [first, last], exercise.values_at(:reference_pitch, :target_pitch).map { |pitch| pitch.tr("♭♯", "b#") }
            assert_equal id, exercise[:correct_option_id]
            assert_equal 1, exercise[:options].count { |option| option[:id] == id }
            assert_equal semitones, (MusicTheory::Note.parse(first).midi - MusicTheory::Note.parse(last).midi).abs
            expected = 440.0 * 2**(((direction == "ascending" ? 60 + semitones : 60) - 69) / 12.0)
            assert_in_delta expected, exercise[:target_frequency], 0.001
            assignment = ExerciseAssignment.issue!(user:, area: "percepcao", exercise:)
            hydrated = assignment.reload.exercise
            assert_equal exercise, hydrated.except(:assignment_id, :attempt_token)
            assert ExerciseIntegrityValidator.validate!("percepcao", hydrated)
          end
        end
      end
    end
  end
end
