require "test_helper"

class AnswerPositionRandomnessTest < ActiveSupport::TestCase
  test "all generators distribute the correct answer across four positions with repeatable test seeds" do
    factories = {
      "interval" => ->(r) { PerceptionIntervalExerciseGenerator.new(random: r).call },
      "melodic legacy" => ->(r) { MelodicDictationExerciseGenerator.new(random: r).call },
      "melodic voices" => ->(r) { VoicedDictationExerciseGenerator.new(level: 4, random: r).call },
      "rhythm legacy" => ->(r) { RhythmExerciseGenerator.new(random: r).call },
      "rhythm meters" => ->(r) { MetricalRhythmExerciseGenerator.new(level: 4, meter_id: "mixed", random: r).call }
    }
    %w[quality scale_degree harmonic_function progression].each do |mode|
      factories["harmony #{mode}"] = ->(r) { HarmonyExerciseGenerator.new(level: 4, question_mode: mode, random: r).call }
    end
    factories.each do |name, build|
      histogram = Array.new(4,0)
      128.times do |seed|
        e = build.call(Random.new(seed))
        index = e[:options].index { |option| option[:id] == e[:correct_option_id] }
        assert index && e[:options].count { |o| o[:id] == e[:correct_option_id] } == 1, name
        histogram[index] += 1
      end
      assert histogram.all? { |count| count.between?(8,64) }, "#{name}: #{histogram.inspect}"
      assert_equal build.call(Random.new(19)), build.call(Random.new(19)), name
      puts "Answer positions #{name}: #{histogram.join('/')}"
    end
  end
end
