require "test_helper"

class ReadingNoteExerciseGeneratorTest < ActiveSupport::TestCase
  test "builds four unique note options with a valid correct answer" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(1234), question_mode: "note_name").call

    assert_equal 4, exercise[:options].size
    assert_equal 4, exercise[:options].pluck(:id).uniq.size
    assert_includes exercise[:options].pluck(:id), exercise[:correct_option_id]
    assert_includes %w[treble bass alto], exercise[:clef_id]
    assert_equal "note_name", exercise[:question_type]
    assert_includes (-6..14).to_a, exercise[:staff_position_index]
    assert_includes %w[level_1 level_2 level_3 level_4], exercise[:season_id]
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

  test "avoids repeating seen staff positions within the same clef and season when possible" do
    exercise = ReadingNoteExerciseGenerator.new(
      random: Random.new(88),
      clef_mode: "treble",
      season_mode: "level_1",
      question_mode: "note_name",
      recent_exercises: [
        { clef_id: "treble", question_type: "note_name", season_id: "level_1", staff_position_index: 0 },
        { clef_id: "treble", question_type: "note_name", season_id: "level_1", staff_position_index: 1 },
        { clef_id: "treble", question_type: "note_name", season_id: "level_1", staff_position_index: 2 }
      ]
    ).call

    refute_includes [0, 1, 2], exercise[:staff_position_index]
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

  test "mixed season mode distributes all configured levels over multiple rounds" do
    recent = []
    counts = Hash.new(0)

    40.times do |index|
      exercise = ReadingNoteExerciseGenerator.new(
        random: Random.new(index + 300),
        season_mode: "mixed",
        question_mode: "note_name",
        recent_exercises: recent
      ).call

      counts[exercise[:season_id]] += 1
      recent << {
        clef_id: exercise[:clef_id],
        question_type: exercise[:question_type],
        season_id: exercise[:season_id],
        signature: exercise[:signature],
        staff_position_index: exercise[:staff_position_index]
      }
      recent = recent.last(6)
    end

    assert_operator counts["level_1"], :>, 0
    assert_operator counts["level_2"], :>, 0
    assert_operator counts["level_3"], :>, 0
    assert_operator counts["level_4"], :>, 0
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
    assert_match(/\A[a-g]__/, exercise[:correct_option_id])
    assert_predicate exercise[:note_accidental_symbol], :present?
    assert_equal 4, exercise[:options].size
    assert_equal exercise[:correct_option_label], exercise[:options].find { |option| option[:id] == exercise[:correct_option_id] }[:label]
    assert_match(/\A[A-ZÁÉÍÓÚÂÊÔÃÕÇa-záéíóúâêôãõç]+\s/, exercise[:correct_option_label])
  end

  test "can generate key signature exercises" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(77), question_mode: "key_signature").call

    assert_equal "key_signature", exercise[:question_type]
    assert_equal "key_signature", exercise[:notation_kind]
    assert_predicate exercise[:key_signature_id], :present?
    assert_operator exercise[:key_signature_accidentals].size, :>=, 0
  end

  test "level 1 keeps reading exercises in the introductory complexity band" do
    note_exercise = ReadingNoteExerciseGenerator.new(
      random: Random.new(12),
      season_mode: "level_1",
      question_mode: "note_name"
    ).call
    accidental_exercise = ReadingNoteExerciseGenerator.new(
      random: Random.new(13),
      season_mode: "level_1",
      question_mode: "accidental"
    ).call
    key_signature_exercise = ReadingNoteExerciseGenerator.new(
      random: Random.new(14),
      season_mode: "level_1",
      question_mode: "key_signature"
    ).call

    assert_equal "level_1", note_exercise[:season_mode]
    assert_equal "level_1", note_exercise[:season_id]
    assert_includes (0..8).to_a, note_exercise[:staff_position_index]
    refute_equal "double_sharp", accidental_exercise[:note_accidental_id]
    assert_includes %w[c_major g_major f_major], key_signature_exercise[:key_signature_id]
  end

  test "bass clef note-name rounds keep varying the generated note" do
    recent = []
    generated_labels = []
    generated_positions = []

    10.times do |index|
      exercise = ReadingNoteExerciseGenerator.new(
        random: Random.new(index + 900),
        clef_mode: "bass",
        question_mode: "note_name",
        season_mode: "level_1",
        recent_exercises: recent
      ).call

      generated_labels << exercise[:correct_option_label]
      generated_positions << exercise[:staff_position_index]
      recent << {
        clef_id: exercise[:clef_id],
        question_type: exercise[:question_type],
        season_id: exercise[:season_id],
        signature: exercise[:signature],
        staff_position_index: exercise[:staff_position_index]
      }
      recent = recent.last(6)
    end

    assert_operator generated_labels.uniq.size, :>, 3
    assert_operator generated_positions.uniq.size, :>, 4
  end

  test "bass clef level 1 cycles through all staff positions before repeating" do
    recent = []
    generated_positions = []

    9.times do |index|
      exercise = ReadingNoteExerciseGenerator.new(
        random: Random.new(index + 1200),
        clef_mode: "bass",
        question_mode: "note_name",
        season_mode: "level_1",
        recent_exercises: recent
      ).call

      generated_positions << exercise[:staff_position_index]
      recent << {
        clef_id: exercise[:clef_id],
        question_type: exercise[:question_type],
        season_id: exercise[:season_id],
        staff_position_index: exercise[:staff_position_index]
      }
      recent = recent.last(24)
    end

    assert_equal generated_positions.uniq.sort, (0..8).to_a
  end

  test "all fixed clefs cycle through introductory staff positions before repeating" do
    %w[treble bass alto].each_with_index do |clef_mode, offset|
      recent = []
      generated_positions = []

      9.times do |index|
        exercise = ReadingNoteExerciseGenerator.new(
          random: Random.new(index + 1500 + offset),
          clef_mode:,
          question_mode: "note_name",
          season_mode: "level_1",
          recent_exercises: recent
        ).call

        generated_positions << exercise[:staff_position_index]
        recent << {
          clef_id: exercise[:clef_id],
          question_type: exercise[:question_type],
          season_id: exercise[:season_id],
          staff_position_index: exercise[:staff_position_index]
        }
        recent = recent.last(24)
      end

      assert_equal (0..8).to_a, generated_positions.uniq.sort, "failed for #{clef_mode}"
    end
  end

  test "level 4 can force ledger-line notes beyond the basic staff range" do
    recent_exercises = ((-5)..14).map do |staff_position_index|
      {
        clef_id: "treble",
        question_type: "note_name",
        season_id: "level_4",
        staff_position_index:
      }
    end

    exercise = ReadingNoteExerciseGenerator.new(
      random: Random.new(2400),
      clef_mode: "treble",
      question_mode: "note_name",
      season_mode: "level_4",
      recent_exercises:
    ).call

    assert_equal -6, exercise[:staff_position_index]
  end

  test "level 4 can generate extended key signatures" do
    recent_exercises = ReadingNoteExerciseGenerator::KEY_SIGNATURES.reject { |definition| definition[:id] == "cs_major" }.map do |definition|
      {
        clef_id: "treble",
        question_type: "key_signature",
        season_id: "level_4",
        key_signature_id: definition[:id]
      }
    end

    exercise = ReadingNoteExerciseGenerator.new(
      random: Random.new(2500),
      clef_mode: "treble",
      question_mode: "key_signature",
      season_mode: "level_4",
      recent_exercises:
    ).call

    assert_equal "cs_major", exercise[:key_signature_id]
    assert_equal 7, exercise[:key_signature_accidentals].size
  end

  test "level 4 can generate double-flat note answers across multiple rounds" do
    recent = []
    generated_accidentals = []

    36.times do |index|
      exercise = ReadingNoteExerciseGenerator.new(
        random: Random.new(index + 2600),
        clef_mode: "alto",
        question_mode: "accidental",
        season_mode: "level_4",
        recent_exercises: recent
      ).call

      generated_accidentals << exercise[:note_accidental_id]
      recent << {
        clef_id: exercise[:clef_id],
        question_type: exercise[:question_type],
        season_id: exercise[:season_id],
        staff_position_index: exercise[:staff_position_index],
        note_accidental_id: exercise[:note_accidental_id]
      }
      recent = recent.last(24)
    end

    assert_includes generated_accidentals, "double_flat"
  end
end
