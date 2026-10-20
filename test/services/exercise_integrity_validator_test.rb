require "test_helper"

class ExerciseIntegrityValidatorTest < ActiveSupport::TestCase
  test "existing generators pass independent arithmetic over a reproducible corpus" do
    250.times do |seed|
      {
        "leitura" => ReadingNoteExerciseGenerator.new(random: Random.new(seed)).call,
        "percepcao" => PerceptionIntervalExerciseGenerator.new(random: Random.new(seed)).call,
        "harmonia" => HarmonyExerciseGenerator.new(random: Random.new(seed), chord_structure: seed.even? ? "triad" : "tetrad").call,
        "ritmica" => RhythmExerciseGenerator.new(random: Random.new(seed)).call
      }.each do |area, exercise|
        assert ExerciseIntegrityValidator.validate!(area, exercise), "#{area} seed #{seed}"
      end
    end
  end

  test "known thirds and descending fifth are proved without the generating library" do
    [["C4", "E4", "major_third", 261.626, 329.628],
     ["C4", "Eb4", "minor_third", 261.626, 311.127],
     ["E4", "A3", "perfect_fifth", 329.628, 220.0]].each do |first, last, answer, f1, f2|
      ids = [answer] + (%w[major_second minor_second perfect_fourth perfect_octave] - [answer]).first(3)
      exercise = { reference_pitch: first, target_pitch: last, reference_frequency: f1, target_frequency: f2,
                   direction: first == "E4" ? "descending" : "ascending", direction_mode: "mixed", direction_mode_label: "Misto",
                   direction_label: first == "E4" ? "Decrescente" : "Crescente", question: "Ouça duas notas consecutivas e identifique o intervalo melódico.", correct_option_id: answer,
                   correct_option_label: PerceptionIntervalExerciseGenerator::INTERVAL_LIBRARY.find { |entry| entry[:id] == answer }[:label],
                   options: ids.map { |id| { id:, label: PerceptionIntervalExerciseGenerator::INTERVAL_LIBRARY.find { |entry| entry[:id] == id }[:label] } } }
      assert ExerciseIntegrityValidator.validate!("percepcao", exercise)
      assert_raises(ExerciseIntegrityValidator::Invalid) do
        ExerciseIntegrityValidator.validate!("percepcao", exercise.merge(correct_option_id: ids.last))
      end
      assert_raises(ExerciseIntegrityValidator::Invalid) do
        ExerciseIntegrityValidator.validate!("percepcao", exercise.merge(target_frequency: Float::NAN))
      end
    end
  end

  test "key signature geometry and duplicate alternatives are rejected" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(0), question_mode: "key_signature").call
    mutated = exercise.deep_dup
    mutated[:key_signature_accidentals] = [{ accidental_id: "sharp", symbol: "♯", staff_position_index: 0 }]
    assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("leitura", mutated) }
    mutated = exercise.deep_dup
    mutated[:options][1] = mutated[:options][0]
    assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("leitura", mutated) }
    mutated = exercise.deep_dup
    mutated[:options][0][:label] = "An unrelated musical answer"
    assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("leitura", mutated) }
  end

  test "harmony audio and progression focus cannot disagree with degree" do
    exercise = HarmonyExerciseGenerator.new(random: Random.new(12), question_mode: "progression").call
    mutated = exercise.deep_dup
    mutated[:audio_sequence][0][:pitches][0] = "C1"
    assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("harmonia", mutated) }
    mutated = exercise.merge(progression_focus_index: 0)
    assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("harmonia", mutated) }
  end

  test "auditory equivalent rhythm options and inconsistent audio are rejected" do
    exercise = RhythmExerciseGenerator.new(random: Random.new(1), activity_mode: "pulse").call
    ids = %w[n4.n4.n4.r4 n4.n4.n4.r2.r2 n4.r4.n4.n4 r4.n4.n4.n4]
    exercise[:options] = ids.map { |id| RhythmExerciseGenerator.option_from_signature(id) }
    exercise[:correct_option_id] = ids.first
    exercise[:correct_option_label] = exercise[:options].first[:aria_label]
    exercise[:audio_events] = RhythmExerciseGenerator.audio_events_for_signature(ids.first)
    error = assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("ritmica", exercise) }
    assert_equal "ambiguous_attacks", error.message

    exercise = RhythmExerciseGenerator.new(random: Random.new(2)).call
    exercise[:audio_events][0][:start_step] += 1
    error = assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("ritmica", exercise) }
    assert_equal "rhythm_audio", error.message
  end
end
