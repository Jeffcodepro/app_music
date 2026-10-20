require "test_helper"

class InstrumentRegisterTest < ActiveSupport::TestCase
  test "all interval levels and directions stay in each instrument concert register" do
    %w[piano flute clarinet guitar organ].each do |instrument|
      (1..4).each do |level|
        %w[ascending descending].each do |direction_mode|
          10.times do |seed|
            e = PerceptionIntervalExerciseGenerator.new(instrument:, level:, direction_mode:, random: Random.new(seed)).call
            assert ExerciseIntegrityValidator.validate!("percepcao", e)
            assert [e[:reference_pitch],e[:target_pitch]].all? { |p| ExerciseInstrumentRegister.range(instrument).cover?(MusicTheory::Note.parse(p).midi) }, "#{instrument}: #{e.slice(:reference_pitch,:target_pitch)}"
          end
        end
      end
    end
  end

  test "harmony shifts notation and frequencies together and validates the register independently" do
    %w[piano flute clarinet guitar organ].each do |instrument|
      (1..4).each do |level|
        ListeningDifficulty.harmony_modes(level).product(ListeningDifficulty.harmony_structures(level)).each do |mode, structure|
        5.times do |seed|
          e = HarmonyExerciseGenerator.new(instrument:, level:, question_mode: mode, chord_structure: structure, random: Random.new(seed)).call
          assert ExerciseIntegrityValidator.validate!("harmonia", e)
          assert e[:audio_sequence].flat_map { |chord| chord[:pitches] }.all? { |p| ExerciseInstrumentRegister.range(instrument).cover?(MusicTheory::Note.parse(p).midi) }
          if %w[flute clarinet].include?(instrument)
            bad = e.deep_dup; bad[:audio_sequence][0][:register_offset] = 1
            assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("harmonia",bad) }
          end
        end
        end
      end
    end
  end

  test "literal high B flat leading seventh inversion is moved down without changing its identity" do
    validator = ExerciseIntegrityValidator.new("harmonia", difficulty_version: "harmony-levels-v1", level: 4, register_version: "concert-register-v1", instrument: "guitar")
    # A4 C5 Eb5 G5, third inversion G5 A5 C6 Eb6, then down one octave.
    root = [{midi:69,diatonic:33},{midi:72,diatonic:35},{midi:75,diatonic:37},{midi:79,diatonic:39}]
    chord = { inversion:3, register_offset:-12, pitches:%w[G4 A4 C5 Eb5], frequencies:[391.995436,440,523.251131,622.253967] }
    assert validator.send(:check_audio_chord,chord,root)
    assert_raises(ExerciseIntegrityValidator::Invalid) { validator.send(:check_audio_chord,chord.merge(register_offset:0),root) }
  end
end
