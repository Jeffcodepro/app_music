require "test_helper"
require "minitest/mock"

class CanonicalMusicIntegrationTest < ActiveSupport::TestCase
  def legacy_exercises
    JSON.parse(File.read(Rails.root.join("test/support/legacy_reading_perception_exercises.json"))).map(&:deep_symbolize_keys)
  end

  test "application eager loading includes pure music values without autoloading the test guard as a constant" do
    Rails.application.eager_load!
    refute MusicTheory::Note < ActiveRecord::Base
    refute MusicTheory::Interval < ActiveRecord::Base
    assert_equal 60, MusicTheory::Note.parse("C4").midi
  end

  test "complete pre-mission payloads signatures and digests remain unchanged" do
    legacy_exercises.each do |entry|
      klass = entry[:area] == "leitura" ? ReadingNoteExerciseGenerator : PerceptionIntervalExerciseGenerator
      actual = klass.new(random: Random.new(entry[:seed]), **entry[:generator_options]).call
      assert_equal entry[:exercise], actual
      assert_equal entry[:digest], ExerciseIntegrityValidator.digest(entry[:area], actual)
      assert ExerciseIntegrityValidator.validate!(entry[:area], entry[:exercise])
    end
  end

  test "legacy assignments can still be rehydrated submitted and replayed with the existing XP policy" do
    user = User.create!(email: "canonical-legacy@example.test", password: "password123", full_name: "Canonical", plan: "Pulso")
    legacy_exercises.each do |entry|
      # Persist the old payload and its pre-mission digest directly, simulating
      # an assignment created before this code existed, rather than reissuing it.
      assignment = ExerciseAssignment.create!(
        user:, area: entry[:area], public_id: SecureRandom.uuid, answer_token: SecureRandom.uuid,
        rules_version: "integrity-2", exercise_payload: entry[:exercise].deep_stringify_keys,
        content_digest: entry[:digest], expires_at: 12.hours.from_now
      )
      assert_equal "integrity-2", assignment.rules_version
      assert_equal entry[:digest], assignment.content_digest
      assert_equal entry[:exercise], assignment.exercise.except(:assignment_id, :attempt_token)
      arguments = { user:, area: entry[:area], assignment_id: assignment.public_id, attempt_token: assignment.answer_token,
                    selected_option_id: entry[:exercise][:correct_option_id], playback_status: "ready" }
      first = ExerciseSubmission.call(**arguments)
      second = ExerciseSubmission.call(**arguments)
      assert first.correct
      assert second.duplicate
      assert_equal 1, assignment.exercise_attempts.count
      assert_equal 20, assignment.study_activity.xp_earned
    end
    assert_equal 20 * legacy_exercises.size, user.study_activities.sum(:xp_earned)
  end

  test "reading adapter separates natural staff position from the resulting alteration and printed glyph" do
    { "double_flat" => [-2, 63, "𝄫"], "flat" => [-1, 64, "♭"], "natural" => [0, 65, "♮"],
      "sharp" => [1, 66, "♯"], "double_sharp" => [2, 67, "𝄪"] }.each do |id, (alter, midi, glyph)|
      exercise = { question_type: "accidental", pitch_name: "F4", note_accidental_id: id }
      note = ExercisePresentation.reading_note(exercise)
      assert_equal({ step: "F", alter:, octave: 4 }, note.to_h)
      assert_equal midi, note.midi
      assert_equal "F4", exercise[:pitch_name]
      assert_equal glyph, ExercisePresentation::ACCIDENTALS.fetch(id)[:symbol]
    end
    natural = ExercisePresentation.reading_note(question_type: "note_name", pitch_name: "F4")
    assert_equal 0, natural.alter
    assert_equal "F4", natural.spelling
  end

  test "reading canonical notes agree with staff geometry and the existing SVG" do
    { "treble" => ["E4", 64], "bass" => ["G2", 43], "alto" => ["F3", 53] }.each do |clef_id, (name, midi)|
      exercise = ReadingNoteExerciseGenerator.new(random: Random.new(7), clef_mode: clef_id, question_mode: "note_name").call
      exercise.merge!(staff_position_index: 0, pitch_name: name)
      note = ExercisePresentation.reading_note(exercise)
      assert_equal midi, note.midi
      clef = HeadMusic::Rudiment::Clef.get(exercise[:head_music_clef])
      assert_equal 0, ReadingNoteExerciseGenerator.staff_position_index_for_pitch(clef:, pitch_name: note.to_s)
      assert_includes ReadingStaffSvgRenderer.new(exercise:).call, '<ellipse cx="286" cy="140"'
    end
  end

  test "the reading adapter rejects missing notes and altered legacy staff pitches" do
    assert_raises(ArgumentError) { ExercisePresentation.reading_note(question_type: "key_signature", key_signature_id: "g_major") }
    assert_raises(ArgumentError) { ExercisePresentation.reading_note(question_type: "accidental", pitch_name: "F#4", note_accidental_id: "natural") }
    assert_raises(KeyError) { ExercisePresentation.reading_note(question_type: "note_name") }
    assert_raises(KeyError) { ExercisePresentation.reading_note(question_type: "accidental", pitch_name: "F4", note_accidental_id: "unknown") }
  end

  test "perception refuses a transposition that disagrees with the selected interval" do
    generator = PerceptionIntervalExerciseGenerator.new(random: Random.new(4), direction_mode: "ascending")
    definition = PerceptionIntervalExerciseGenerator::INTERVAL_LIBRARY.find { |entry| entry[:id] == "major_third" }
    generator.stub(:sampled_interval_definition, definition) do
      generator.stub(:sampled_reference_pitch, MusicTheory::Note.parse("C4")) do
        generator.stub(:build_target_pitch, MusicTheory::Note.parse("F4")) do
          assert_raises(ArgumentError) { generator.call }
        end
      end
    end
  end

  test "perception frequencies are calculated by the canonical note rather than the transposition library" do
    pitch_class = HeadMusic::Rudiment::Pitch
    legacy_frequency = pitch_class.instance_method(:frequency)
    pitch_class.define_method(:frequency) { raise "legacy frequency must not be used" }
    exercise = PerceptionIntervalExerciseGenerator.new(random: Random.new(4)).call
    assert_equal MusicTheory::Note.parse(exercise[:reference_pitch]).frequency.round(3), exercise[:reference_frequency]
    assert ExerciseIntegrityValidator.validate!("percepcao", exercise)
  ensure
    pitch_class.define_method(:frequency, legacy_frequency)
  end

  test "the independent validator rejects an augmented third mislabeled as a fourth and pitches outside MIDI" do
    entry = legacy_exercises.find { |item| item[:area] == "percepcao" }
    exercise = entry[:exercise].deep_dup
    exercise.merge!(reference_pitch: "C4", target_pitch: "E#4", reference_frequency: 261.626, target_frequency: 349.228,
                    direction: "ascending", direction_mode: "ascending", direction_mode_label: "Ascendente", direction_label: "Crescente",
                    correct_option_id: "perfect_fourth", correct_option_label: "Quarta justa (P4)")
    exercise[:options] = [
      { id: "perfect_fourth", label: "Quarta justa (P4)" }, { id: "major_third", label: "Terça maior (M3)" },
      { id: "minor_third", label: "Terça menor (m3)" }, { id: "perfect_fifth", label: "Quinta justa (P5)" }
    ]
    assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("percepcao", exercise) }
    exercise.merge!(reference_pitch: "C10", target_pitch: "F10", reference_frequency: 16744.036, target_frequency: 22350.607)
    assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("percepcao", exercise) }
  end

  test "both playgrounds share localization while preserving natural spelling and explicit doubles" do
    { "C4" => "Dó 4", "F#4" => "Fá sustenido 4", "Bb3" => "Si bemol 3",
      "C##4" => "Dó duplo sustenido 4", "Dbb4" => "Ré duplo bemol 4" }.each do |name, label|
      assert_equal label, ReadingNoteExerciseGenerator.localize_pitch_name(name)
      assert_equal label, PerceptionIntervalExerciseGenerator.localize_pitch_name(name)
    end
  end
end
