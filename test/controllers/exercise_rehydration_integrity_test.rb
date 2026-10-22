require "test_helper"

class ExerciseRehydrationIntegrityTest < ActionController::TestCase
  tests StudentHubController

  test "reading hydration rejects a wrong answer or inconsistent position" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(0), clef_mode: "treble", question_mode: "note_name", season_mode: "level_1").call
    payload = @controller.send(:compact_reading_exercise_storage, exercise)
    wrong = (payload.fetch("o") - [payload.fetch("a")]).first
    assert_nil @controller.send(:hydrate_reading_exercise, payload.merge("a" => wrong))
    assert_nil @controller.send(:hydrate_reading_exercise, payload.merge("i" => 1))
  end

  test "harmony hydration rejects an answer unrelated to the chord" do
    exercise = HarmonyExerciseGenerator.new(random: Random.new(0), question_mode: "quality").call
    payload = @controller.send(:compact_harmony_exercise_storage, exercise)
    wrong = (payload.fetch("o") - [payload.fetch("a")]).first
    assert_nil @controller.send(:hydrate_harmony_exercise, payload.merge("a" => wrong))
  end
end
