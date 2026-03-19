require "test_helper"

class ReadingNoteExerciseGeneratorTest < ActiveSupport::TestCase
  test "builds four unique note options with a valid correct answer" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(1234), question_mode: "note_name").call

    assert_equal 4, exercise[:options].size
    assert_equal 4, exercise[:options].pluck(:id).uniq.size
    assert_includes exercise[:options].pluck(:id), exercise[:correct_option_id]
    assert_includes %w[treble bass alto], exercise[:clef_id]
    assert_equal "note_name", exercise[:question_type]
    assert_includes (-2..10).to_a, exercise[:staff_position_index]
  end

  test "keeps the requested clef mode fixed when selected" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(99), clef_mode: "bass", question_mode: "note_name").call

    assert_equal "bass", exercise[:clef_id]
    assert_equal "bass", exercise[:clef_mode]
    assert_equal "Somente Fá", exercise[:clef_mode_label]
    assert_equal "Clave de Fá", exercise[:clef_label]
  end

  test "matches the stored pitch with the generated clef and staff position" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(2026), clef_mode: "alto", question_mode: "note_name").call
    clef = HeadMusic::Rudiment::Clef.get(exercise[:head_music_clef])
    staff_position_index = exercise[:staff_position_index]
    pitch = if staff_position_index.even?
              clef.pitch_for_line((staff_position_index / 2) + 1)
            else
              clef.pitch_for_space(((staff_position_index - 1) / 2) + 1)
            end

    assert_equal exercise[:pitch_name], pitch.to_s
  end

  test "avoids immediately repeating recent signatures when possible" do
    exercise = ReadingNoteExerciseGenerator.new(
      random: Random.new(88),
      question_mode: "note_name",
      recent_exercises: [
        { clef_id: "treble", question_type: "note_name", signature: "note_name|treble|C4" },
        { clef_id: "bass", question_type: "note_name", signature: "note_name|bass|G2" }
      ]
    ).call

    refute_includes ["note_name|treble|C4", "note_name|bass|G2"], exercise[:signature]
  end

  test "mixed mode distributes all configured clefs over multiple rounds" do
    recent = []
    counts = Hash.new(0)

    24.times do |index|
      exercise = ReadingNoteExerciseGenerator.new(
        random: Random.new(index + 100),
        clef_mode: "mixed",
        question_mode: "note_name",
        recent_exercises: recent
      ).call

      counts[exercise[:clef_id]] += 1
      recent << {
        clef_id: exercise[:clef_id],
        question_type: exercise[:question_type],
        signature: exercise[:signature],
        staff_position_index: exercise[:staff_position_index]
      }
      recent = recent.last(6)
    end

    assert_operator counts["bass"], :>, 0
    assert_operator counts["treble"], :>, 0
    assert_operator counts["alto"], :>, 0
  end

  test "avoids repeating the same recent staff position within a clef when possible" do
    exercise = ReadingNoteExerciseGenerator.new(
      random: Random.new(55),
      clef_mode: "alto",
      question_mode: "note_name",
      recent_exercises: [
        { clef_id: "alto", question_type: "note_name", signature: "note_name|alto|C4", staff_position_index: 4 },
        { clef_id: "alto", question_type: "note_name", signature: "note_name|alto|D4", staff_position_index: 5 }
      ]
    ).call

    refute_includes [4, 5], exercise[:staff_position_index]
  end

  test "can generate accidental identification exercises" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(44), question_mode: "accidental").call

    assert_equal "accidental", exercise[:question_type]
    assert_includes %w[sharp flat natural double_sharp], exercise[:correct_option_id]
    assert_predicate exercise[:note_accidental_symbol], :present?
    assert_equal 4, exercise[:options].size
  end

  test "can generate key signature exercises" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(77), question_mode: "key_signature").call

    assert_equal "key_signature", exercise[:question_type]
    assert_equal "key_signature", exercise[:notation_kind]
    assert_predicate exercise[:key_signature_id], :present?
    assert_operator exercise[:key_signature_accidentals].size, :>=, 1
  end
end
