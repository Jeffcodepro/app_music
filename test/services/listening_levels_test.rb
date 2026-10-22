require "test_helper"

class ListeningLevelsTest < ActiveSupport::TestCase
  test "unleveled harmony matches the eight literal pre-change payloads exactly" do
    JSON.parse(File.read(Rails.root.join("test/support/legacy_harmony_unleveled.json"))).each do |entry|
      generated = HarmonyExerciseGenerator.new(random: Random.new(entry["seed"]), question_mode: entry["mode"], chord_structure: entry["structure"]).call
      assert_equal entry["exercise"], generated.deep_stringify_keys
      assert ExerciseIntegrityValidator.validate!("harmonia", entry["exercise"])
    end
  end

  test "perception restricts answers distractors and exhausted recency to the level" do
    (1..4).each do |level|
      20.times do |seed|
        e = PerceptionIntervalExerciseGenerator.new(level:, random: Random.new(seed), recent_exercises: PerceptionIntervalExerciseGenerator::INTERVAL_LIBRARY.map { |i| { interval_id: i[:id] } }).call
        assert_equal level, e[:level]
        assert ExerciseIntegrityValidator.validate!("percepcao", e)
        assert e[:options].all? { |o| ListeningDifficulty.intervals(level).include?(o[:id]) }
      end
    end
    assert_equal %w[major_second major_third perfect_fourth perfect_fifth perfect_octave], ListeningDifficulty.intervals(1)
  end

  test "harmony limits content and level four uses verified inversions" do
    (1..4).each do |level|
      12.times do |seed|
        e = HarmonyExerciseGenerator.new(level:, random: Random.new(seed)).call
        assert_equal level, e[:level]
        assert ExerciseIntegrityValidator.validate!("harmonia", e)
        assert e[:audio_sequence].all? { |a| a[:inversion].is_a?(Integer) && (level == 4 ? a[:inversion].positive? : a[:inversion].zero?) }
      end
    end
  end

  test "every supported harmony mode and structure stays within its level under recency pressure" do
    (1..4).each do |level|
      ListeningDifficulty.harmony_modes(level).product(ListeningDifficulty.harmony_structures(level)).each do |mode, structure|
        5.times do |seed|
          e = HarmonyExerciseGenerator.new(level:, question_mode: mode, chord_structure: structure, random: Random.new(seed),
            recent_exercises: HarmonyExerciseGenerator::MAJOR_KEYS.map { |key| { key_id: key[:id], degree: seed+1, question_type: mode } }).call
          assert ExerciseIntegrityValidator.validate!("harmonia", e)
          refute_match(/[A-G]\d/, e[:chord_notes_label])
        end
      end
    end
  end

  test "legacy payloads remain valid and inconsistent levels are rejected" do
    assert ExerciseIntegrityValidator.validate!("percepcao", PerceptionIntervalExerciseGenerator.new.call)
    assert ExerciseIntegrityValidator.validate!("harmonia", HarmonyExerciseGenerator.new.call)
    [PerceptionIntervalExerciseGenerator.new(level: 4).call, HarmonyExerciseGenerator.new(level: 4).call].each do |e|
      area = e[:difficulty_version].start_with?("perception") ? "percepcao" : "harmonia"
      bad = e.deep_dup; bad[:level] = "4"
      assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!(area, bad) }
      bad = e.deep_dup; bad[:difficulty_version] = "unknown"
      assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!(area, bad) }
    end
  end

  test "independent literal C major inversions and invalid inversion indices" do
    triad = [{ midi: 48, diatonic: 21 }, { midi: 52, diatonic: 23 }, { midi: 55, diatonic: 25 }]
    tetrad = triad + [{ midi: 59, diatonic: 27 }]
    validator = ExerciseIntegrityValidator.new("harmonia", difficulty_version: "harmony-levels-v1", level: 4)
    [[triad, 1, %w[E3 G3 C4], [164.813778,195.997718,261.625565]],
     [triad, 2, %w[G3 C4 E4], [195.997718,261.625565,329.627557]],
     [tetrad, 3, %w[B3 C4 E4 G4], [246.941651,261.625565,329.627557,391.995436]]].each do |root, inversion, pitches, frequencies|
      chord = { inversion:, pitches:, frequencies: }
      assert validator.send(:check_audio_chord, chord, root)
      [0,-1,1.5,"1",nil,root.size].each do |invalid|
        assert_raises(ExerciseIntegrityValidator::Invalid) { validator.send(:check_audio_chord, chord.merge(inversion: invalid), root) }
      end
      assert_raises(ExerciseIntegrityValidator::Invalid) { validator.send(:check_audio_chord, chord.merge(pitches: pitches.reverse), root) }
    end
  end
end
