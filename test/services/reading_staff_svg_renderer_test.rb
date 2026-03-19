require "test_helper"

class ReadingStaffSvgRendererTest < ActiveSupport::TestCase
  test "renders staff lines, a note and a clef" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(12), clef_mode: "treble", question_mode: "note_name").call
    svg = ReadingStaffSvgRenderer.new(exercise:).call

    assert_includes svg, "<svg"
    assert_includes svg, "<ellipse"
    assert_includes svg, "<text"
    assert_includes svg, "aria-label"
  end

  test "renders the bass clef with a text glyph" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(22), clef_mode: "bass", question_mode: "note_name").call
    svg = ReadingStaffSvgRenderer.new(exercise:).call

    assert_includes svg, "𝄢"
    assert_includes svg, "font-family"
  end

  test "renders key signature accidentals when the exercise asks about armadura" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(31), clef_mode: "treble", question_mode: "key_signature").call
    svg = ReadingStaffSvgRenderer.new(exercise:).call

    assert_match(/[♯♭]/, svg)
    refute_includes svg, "<ellipse"
  end
end
