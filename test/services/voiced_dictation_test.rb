require "test_helper"

class VoicedDictationTest < ActiveSupport::TestCase
  test "levels change note count rhythm and independent voices with four acoustic choices" do
    (1..4).each do |level|
      15.times do |seed|
        e = VoicedDictationExerciseGenerator.new(level:, random: Random.new(seed)).call
        assert ExerciseIntegrityValidator.validate!("percepcao", e)
        assert_equal [1,1,2,nil][level-1], e[:voice_count] if level < 4
        assert_includes [3,4], e[:voice_count] if level == 4
        assert e[:options].all? { |o| o[:voices].all? { |v| v[:events].sum { |n| n[:duration_steps] } == e[:total_steps] } }
      end
    end
  end

  test "validator rejects corrupt timing frequency answer count and acoustically swapped voices" do
    e = VoicedDictationExerciseGenerator.new(level: 4, random: Random.new(2)).call
    [->(v){v[:audio_events][0][:frequency]=1}, ->(v){v[:options][0][:voices][0][:events][0][:duration_steps]=0},
      ->(v){v[:voice_count]=1}, ->(v){v[:total_steps]=31}, ->(v){v[:correct_option_id]='missing'},
      ->(v){v[:options][1][:voices]=v[:options][0][:voices].reverse},
      ->(v){v[:options][1][:voices]=v[:options][0][:voices].deep_dup},
      ->(v){v[:options][0][:voices].drop(1).each { |voice| octave=voice[:events][0][:pitch][-1]; voice[:events]=v[:options][0][:voices][0][:events].map { |e| e.merge(pitch: e[:pitch][0]+octave) } }},
      ->(v){v[:dictation_format]='unknown'}].each do |mutate|
      bad=e.deep_dup;mutate.call(bad);bad[:signature]=VoicedDictationExerciseGenerator.signature(bad)
      assert_raises(ExerciseIntegrityValidator::Invalid){ExerciseIntegrityValidator.validate!("percepcao",bad)}
    end
  end
end
