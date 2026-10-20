require "test_helper"

class ReadingClefIntegrityTest < ActiveSupport::TestCase
  test "rendering clef anchor identity must agree with the musical staff clef" do
    { "treble" => "treble_clef", "bass" => "bass_clef", "alto" => "alto_clef" }.each do |clef, anchor|
      %w[note_name accidental key_signature].each do |mode|
        exercise = ReadingNoteExerciseGenerator.new(random: Random.new(17), clef_mode: clef, question_mode: mode).call
        assert_equal anchor, exercise[:head_music_clef]
        assert ExerciseIntegrityValidator.validate!("leitura", exercise)
        corrupted = exercise.merge(head_music_clef: clef == "bass" ? "treble_clef" : "bass_clef")
        error = assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("leitura", corrupted) }
        assert_equal "clef_identity", error.message
      end
    end
  end
end
