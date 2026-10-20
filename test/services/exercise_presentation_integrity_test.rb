require "test_helper"
require "minitest/mock"

class ExercisePresentationIntegrityTest < ActiveSupport::TestCase
  def rejects(area, exercise, changes)
    assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!(area, exercise.deep_merge(changes)) }
  end

  test "accidental symbols and labels must agree with identity and rendered notation" do
    exercise = ReadingNoteExerciseGenerator.new(random: Random.new(2), question_mode: "accidental").call
    rejects("leitura", exercise, note_accidental_symbol: "WRONG")
    rejects("leitura", exercise, note_accidental_label: "WRONG")
  end

  test "direction mode and presentation must agree with actual ordered pitches" do
    exercise = PerceptionIntervalExerciseGenerator.new(random: Random.new(2), direction_mode: "descending").call
    rejects("percepcao", exercise, direction_mode: "ascending", direction_mode_label: "Ascendente")
    rejects("percepcao", exercise, direction_mode: "unknown")
    rejects("percepcao", exercise, direction_label: "Crescente")
    rejects("percepcao", exercise, question: "Ouça o intervalo ascendente.")
  end

  test "progression question prompt context and visual focus must agree with index" do
    exercise = HarmonyExerciseGenerator.new(random: Random.new(12), question_mode: "progression").call
    rejects("harmonia", exercise, question: "Identifique o grau na 99ª posição.")
    rejects("harmonia", exercise, prompt_value: "Qual grau apareceu na 99ª posição?")
    rejects("harmonia", exercise, progression_steps: exercise[:progression_steps].map { |step| step.merge(focus: false) })
    rejects("harmonia", exercise, context_items: exercise[:context_items].map { |item| item[:label] == "Alvo" ? item.merge(value: "99ª posição") : item })
  end

  test "each valid progression position derives matching text and exactly one visual focus" do
    (1..4).each do |focus|
      generator = HarmonyExerciseGenerator.new(random: Random.new(12), question_mode: "progression")
      generator.stub(:sampled_progression_focus_position, focus) do
        exercise = generator.call
        assert ExerciseIntegrityValidator.validate!("harmonia", exercise)
        assert_includes exercise[:question], "#{focus}ª posição"
        assert_equal [focus - 1], exercise[:progression_steps].each_index.select { |index| exercise[:progression_steps][index][:focus] }
        [0, -1, 5, 99, "1", nil].each { |invalid| rejects("harmonia", exercise, progression_focus_index: invalid) }
      end
    end
  end

  test "quarter notes cannot be published as syncopation" do
    exercise = RhythmExerciseGenerator.new(random: Random.new(5), activity_mode: "pulse").call
    config = RhythmExerciseGenerator.mode_config("syncopation")
    exercise.merge!(activity_mode: "syncopation", activity_mode_label: "Síncopa", tempo_bpm: 90,
                    metronome_during_pattern: config[:metronome_during_pattern], playback_cycles: config[:playback_cycles])
    rejects("ritmica", exercise, {})
    assert_raises(RhythmExerciseGenerator::GenerationError) do
      RhythmExerciseGenerator.new(activity_mode: "syncopation").call
    end
  end

  test "all five explicit accidentals retain their spelling through validation and SVG" do
    reference = { "sharp" => ["♯", "Sustenido"], "flat" => ["♭", "Bemol"], "natural" => ["♮", "Bequadro"],
                  "double_sharp" => ["𝄪", "Duplo sustenido"], "double_flat" => ["𝄫", "Duplo bemol"] }
    base = ReadingNoteExerciseGenerator.new(random: Random.new(2), question_mode: "accidental").call
    letter = base[:pitch_name][0].downcase
    reference.each do |id, (symbol, label)|
      option_ids = [id] + (reference.keys - [id]).first(3)
      options = option_ids.map { |accidental| ReadingNoteExerciseGenerator.accidental_note_option("#{letter}__#{accidental}") }
      exercise = base.merge(note_accidental_id: id, note_accidental_symbol: symbol, note_accidental_label: label,
                            correct_option_id: "#{letter}__#{id}", correct_option_label: options.first[:label], options:)
      assert ExerciseIntegrityValidator.validate!("leitura", exercise)
      assert_includes ReadingStaffSvgRenderer.new(exercise:).call, symbol
      svg = ReadingStaffSvgRenderer.new(exercise: exercise.merge(note_accidental_symbol: "WRONG")).call
      assert_includes svg, symbol
      refute_includes svg, "WRONG"
      rejects("leitura", exercise, note_accidental_symbol: "WRONG")
      rejects("leitura", exercise, note_accidental_label: "WRONG")
    end
    plain = ReadingNoteExerciseGenerator.new(question_mode: "note_name").call
    assert ExerciseIntegrityValidator.validate!("leitura", plain)
    rejects("leitura", plain, note_accidental_id: "sharp", note_accidental_symbol: "♯")
  end

  test "ascending descending and mixed keep pitch order and frequency order consistent" do
    %w[ascending descending mixed].each do |mode|
      12.times do |seed|
        exercise = PerceptionIntervalExerciseGenerator.new(random: Random.new(seed), direction_mode: mode).call
        assert ExerciseIntegrityValidator.validate!("percepcao", exercise)
        rejects("percepcao", exercise, reference_frequency: exercise[:target_frequency], target_frequency: exercise[:reference_frequency])
      end
    end
  end

  test "available rhythmic modes satisfy independently checked beat grouping" do
    exercise = RhythmExerciseGenerator.new(random: Random.new(4), activity_mode: "pulse").call
    config = RhythmExerciseGenerator.mode_config("precision")
    corrupted = exercise.merge(activity_mode: "precision", activity_mode_label: "Precisão", tempo_bpm: 90,
                               question: config[:description], prompt_value: config[:prompt_value], focus_label: config[:focus_label],
                               metronome_during_pattern: config[:metronome_during_pattern], playback_cycles: config[:playback_cycles])
    rejects("ritmica", corrupted, {})
    refute_includes RhythmExerciseGenerator.activity_mode_ids, "syncopation"
    # This is offbeat articulation separated by rests (contratempo), without
    # a note sustained over the following strong beat. Do not call it syncopation.
    offbeats = "r2.n2.r2.n2.r2.n2.r2.n2"
    corrupted[:activity_mode] = "syncopation"
    corrupted[:correct_option_id] = offbeats
    rejects("ritmica", corrupted, {})
  end

  test "contradictions cannot create assignments or grant credit even with a matching digest" do
    user = User.create!(email: "presentation@example.test", password: "password123", full_name: "Presentation", plan: "Pulso")
    cases = [
      ["leitura", ReadingNoteExerciseGenerator.new(question_mode: "accidental").call, { note_accidental_symbol: "WRONG" }],
      ["percepcao", PerceptionIntervalExerciseGenerator.new(direction_mode: "descending").call, { direction_mode: "ascending" }],
      ["harmonia", HarmonyExerciseGenerator.new(question_mode: "progression").call, { question: "99ª posição" }],
      ["ritmica", RhythmExerciseGenerator.new(activity_mode: "pulse").call, { activity_mode: "syncopation" }]
    ]
    cases.each do |area, valid, changes|
      corrupted = valid.merge(changes)
      assert_no_difference "ExerciseAssignment.count" do
        assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseAssignment.issue!(user:, area:, exercise: corrupted) }
      end
      assignment = ExerciseAssignment.issue!(user:, area:, exercise: valid)
      # Simulate corrupt storage, including its digest, so the independent
      # semantic check, rather than just a checksum mismatch, must reject it.
      ExerciseAssignment.where(id: assignment.id).update_all(exercise_payload: corrupted, content_digest: ExerciseIntegrityValidator.digest(area, corrupted))
      assert_no_difference ["ExerciseAttempt.count", "StudyActivity.count"] do
        assert_raises(ExerciseSubmission::Rejected) do
          ExerciseSubmission.call(user:, area:, assignment_id: assignment.public_id, attempt_token: assignment.answer_token,
                                  selected_option_id: valid[:correct_option_id], playback_status: "ready")
        end
      end
    end
  end
end
