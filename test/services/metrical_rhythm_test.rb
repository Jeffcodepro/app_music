require "test_helper"

class MetricalRhythmTest < ActiveSupport::TestCase
  test "approved levels have cumulative formula catalogs and independent meter arithmetic" do
    assert_equal %w[2/4 3/4 4/4], MusicTheory::Meter.presets(level: 1).map { |p| MusicTheory::Meter.fetch(p[:id]).label }
    assert_equal 32, MusicTheory::Meter.presets.map { |p| [p[:numerator], p[:denominator]] }.uniq.size
    { "3-4" => [12, 4, [0,4,8]], "6-8" => [12, 6, [0,6]], "2-2" => [16,8,[0,8]],
      "9-16" => [9,3,[0,3,6]], "5-8-2-3" => [10,2,[0,4]] }.each do |id, expected|
      meter = MusicTheory::Meter.fetch(id)
      assert_equal expected, [meter.measure_steps, meter.bpm_unit_steps, meter.group_starts]
    end
    assert_equal "semínima pontuada", MusicTheory::Meter.fetch("6-8").bpm_unit_label
    assert_equal "mínima pontuada", MusicTheory::Meter.fetch("6-4").bpm_unit_label
    assert_equal "colcheia pontuada", MusicTheory::Meter.fetch("6-16").bpm_unit_label
    assert_raises(ArgumentError) { MusicTheory::Meter.fetch("6-8", level: 1) }
  end

  test "every approved preset supports four distinct complete choices in each available mode" do
    MusicTheory::Meter.presets.each_with_index do |preset, seed|
      %w[pulse subdivision precision mixed].each do |mode|
        exercise = MetricalRhythmExerciseGenerator.new(level: preset[:level], meter_id: preset[:id], activity_mode: mode, random: Random.new(seed)).call
        assert ExerciseIntegrityValidator.validate!("ritmica", exercise), "#{preset[:id]} #{mode}"
        attacks = exercise[:options].map { |o| MetricalRhythmExerciseGenerator.events(o[:id]).map { |e| e[:start_step] } }
        assert_equal 4, attacks.uniq.size
        exercise[:options].each { |o| assert_equal exercise[:total_steps], o[:tokens].sum { |t| t[:duration_steps] } }
      end
    end
  end

  test "generation stays valid over multiple seeds and all presets without loosening musical criteria" do
    MusicTheory::Meter.presets.each do |preset|
      10.times do |seed|
        %w[pulse subdivision precision].each do |mode|
          e = MetricalRhythmExerciseGenerator.new(level: preset[:level], meter_id: preset[:id], activity_mode: mode, random: Random.new(seed)).call
          assert ExerciseIntegrityValidator.validate!("ritmica", e)
        end
      end
    end
  end

  test "two bars in pulse 2/4 are real bars in a single pass and three-beat generation does not exhaust" do
    e = MetricalRhythmExerciseGenerator.new(level: 1, meter_id: "2-4", activity_mode: "pulse").call
    assert_equal [2, 16, 2, 1], e.values_at(:measure_count, :total_steps, :count_in_beats, :playback_cycles)
    recent = []
    20.times do
      e = MetricalRhythmExerciseGenerator.new(level: 1, meter_id: "3-4", activity_mode: "pulse", recent_exercises: recent).call
      assert ExerciseIntegrityValidator.validate!("ritmica", e)
      recent << { pattern_signature: e[:correct_option_id] }
    end
  end

  test "independent validation rejects incompatible meter grouping duration answer and audio" do
    original = MetricalRhythmExerciseGenerator.new(level: 2, meter_id: "6-8", activity_mode: "pulse").call
    mutations = [->(e){e[:meter][:groups]=[2,2,2]}, ->(e){e[:meter][:bpm_unit_steps]=4}, ->(e){e[:level]=1},
      ->(e){e[:time_signature_label]="3/4"}, ->(e){e[:measure_count]=1}, ->(e){e[:total_steps]=16},
      ->(e){e[:tempo_bpm]=0}, ->(e){e[:options][0][:id]+="."}, ->(e){e[:audio_events][0][:start_step]+=1},
      ->(e){e[:options][1]=e[:options][0].deep_dup}, ->(e){e[:correct_option_id]="missing"},
      ->(e){e[:rhythm_format]="unknown"}, ->(e){e[:playback_cycles]=2},
      ->(e){e[:measure_count]=2.0}, ->(e){e[:total_steps]=24.0},
      ->(e){e[:meter][:groups]=[3.0,3.0]}, ->(e){e[:meter][:bpm_unit_steps]=6.0},
      ->(e){e[:audio_events][0][:start_step]=0.0}]
    mutations.each do |mutate|
      e=original.deep_dup;mutate.call(e)
      e[:signature] = MetricalRhythmExerciseGenerator.signature(e)
      assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("ritmica", e) }
    end
  end
  test "validator enforces the generator density bound even with a recomputed signature" do
    e = MetricalRhythmExerciseGenerator.new(level: 3, meter_id: "12-4", activity_mode: "precision").call
    signatures = (0..3).map { |rest| Array.new(48) { |i| i == rest ? "r1" : "n1" }.join('.') }
    e[:options] = signatures.map { |signature| MetricalRhythmExerciseGenerator.option(signature) }
    e[:correct_option_id] = signatures.first
    e[:correct_option_label] = e[:options].first[:aria_label]
    e[:audio_events] = MetricalRhythmExerciseGenerator.events(signatures.first)
    e[:signature] = MetricalRhythmExerciseGenerator.signature(e)
    assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("ritmica", e) }
  end

end
