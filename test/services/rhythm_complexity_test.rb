require "test_helper"

class RhythmComplexityTest < ActiveSupport::TestCase
  test "level one has regular eighths while higher levels introduce finer and varied structures" do
    %w[subdivision precision].each do |mode|
      patterns = (1..4).to_h do |level|
        examples = 12.times.map { |seed| MetricalRhythmExerciseGenerator.new(level:, meter_id: "4-4", activity_mode: mode, random: Random.new(seed)).call }
        assert examples.all? { |e| e[:complexity_version] == "level-structure-v1" }
        [level, examples.flat_map { |e| e[:options] }]
      end
      assert patterns[1].all? { |o| o[:tokens].all? { |t| [2,4].include?(t[:duration_steps]) } }
      assert patterns[2].any? { |o| o[:tokens].any? { |t| t[:duration_steps] == 1 } }
      assert patterns[3].any? { |o| o[:pattern_signature].match?(/(?:[nr]1\.){3}[nr]1/) }
      assert patterns[4].all? { |o| o[:tokens][1...-1].any? { |t| t[:kind] == "rest" } }
    end
  end

  test "new profile is independently validated while pre-profile assignments stay valid" do
    fixture = JSON.parse(File.read(Rails.root.join("test/support/legacy_metrical_rhythm.json"))).deep_symbolize_keys
    assert ExerciseIntegrityValidator.validate!("ritmica", fixture)
    assert fixture[:options].any? { |o| o[:tokens].any? { |t| t[:duration_steps] == 1 } }, "Legacy level 1 allowed sixteenths"
    exercise = MetricalRhythmExerciseGenerator.new(level: 1, meter_id: "4-4", activity_mode: "precision").call
    assert ExerciseIntegrityValidator.validate!("ritmica", exercise)
    legacy = exercise.except(:complexity_version, :requested_meter_id)
    legacy[:signature] = MetricalRhythmExerciseGenerator.signature(legacy)
    assert ExerciseIntegrityValidator.validate!("ritmica", legacy)
    [->(e) { e[:complexity_version] = "unknown" }, ->(e) { e.delete(:requested_meter_id) }, ->(e) { e[:requested_meter_id] = "6-8" }].each do |mutate|
      bad = exercise.deep_dup; mutate.call(bad); bad[:signature] = MetricalRhythmExerciseGenerator.signature(bad)
      assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("ritmica", bad) }
    end
    advanced = MetricalRhythmExerciseGenerator.new(level: 4, meter_id: "4-4", activity_mode: "precision", random: Random.new(7)).call
    advanced[:level] = 1; advanced[:signature] = MetricalRhythmExerciseGenerator.signature(advanced)
    assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("ritmica", advanced) }
  end

  test "mixed meter resolves within the level catalog and keeps the requested preference" do
    (1..4).each do |level|
      meters = 20.times.map do |seed|
        e = MetricalRhythmExerciseGenerator.new(level:, meter_id: "mixed", random: Random.new(seed)).call
        assert_equal "mixed", e[:requested_meter_id]
        assert ExerciseIntegrityValidator.validate!("ritmica", e)
        e[:meter_id]
      end
      assert_operator meters.uniq.size, :>, 1
    end
  end

  test "all cumulative level catalogs remain generatable including small advanced meters" do
    (1..4).each do |level|
      MusicTheory::Meter.presets(level:).each do |preset|
        %w[pulse subdivision precision].each do |mode|
          3.times do |seed|
            e = MetricalRhythmExerciseGenerator.new(level:, meter_id: preset[:id], activity_mode: mode, random: Random.new(seed)).call
            assert ExerciseIntegrityValidator.validate!("ritmica", e), "level #{level}, #{preset[:id]}, #{mode}, seed #{seed}"
          end
        end
      end
    end
    100.times do |seed|
      assert ExerciseIntegrityValidator.validate!("ritmica", MetricalRhythmExerciseGenerator.new(level: 4, meter_id: "2-8", activity_mode: "precision", random: Random.new(seed)).call)
    end
  end

  test "advanced subdivision rejects elementary patterns even with a recomputed signature" do
    e = MetricalRhythmExerciseGenerator.new(level: 4, meter_id: "4-4", activity_mode: "subdivision").call
    signatures = %w[n2.n2.r4.n4.n4 n4.n2.n2.r4.n4 n4.r4.n2.n2.n4 n4.r4.n4.n2.n2]
    e[:options] = signatures.map { |s| MetricalRhythmExerciseGenerator.option(s) }
    e[:correct_option_id] = signatures.first
    e[:correct_option_label] = e[:options].first[:aria_label]
    e[:audio_events] = MetricalRhythmExerciseGenerator.events(signatures.first)
    e[:signature] = MetricalRhythmExerciseGenerator.signature(e)
    assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("ritmica", e) }
  end
end
