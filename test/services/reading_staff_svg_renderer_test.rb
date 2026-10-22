require "test_helper"

class ReadingStaffSvgRendererTest < ActiveSupport::TestCase
  test "viewBox reserves glyph space for double accidentals at both ledger extremes" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(12)).call
    [-6, 14].each do |position|
      svg = Nokogiri::XML(ReadingStaffSvgRenderer.new(exercise: exercise.merge(
        staff_position_index: position, notation_kind: "note", note_accidental_id: "double_sharp"
      )).call)
      _, top, _, height = svg.at_css("svg")["viewBox"].split.map(&:to_f)
      note_y = 140 - position * 9
      assert_operator top, :<=, note_y - 32
      assert_operator top + height, :>=, note_y + 32
      assert_equal note_y, svg.at_css("ellipse")["cy"].to_f
    end
  end

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

  test "renders multiple ledger lines for notes well outside the staff" do
    exercise = ReadingNoteExerciseGenerator.new(
      random: Random.new(4000),
      clef_mode: "treble",
      question_mode: "note_name",
      season_mode: "level_4",
      recent_exercises: ((-5)..14).map do |staff_position_index|
        {
          clef_id: "treble",
          question_type: "note_name",
          season_id: "level_4",
          staff_position_index:
        }
      end
    ).call

    svg = ReadingStaffSvgRenderer.new(exercise:).call

    assert_equal(-6, exercise[:staff_position_index])
    assert_operator svg.scan("<line").size, :>=, 8
  end
end
