require "test_helper"

class GrandStaffDictationTest < ActiveSupport::TestCase
  test "four voices share two staves with opposed stems and unchanged music" do
    exercise = (0...20).map { |seed| VoicedDictationExerciseGenerator.new(level: 4, random: Random.new(seed)).call }.find { |e| e[:voice_count] == 4 }
    option = exercise[:options].first
    before = option.deep_dup
    svg = Nokogiri::XML(VoicedDictationSvgRenderer.new(voices: option[:voices], total_steps: exercise[:total_steps]).call)
    svg.remove_namespaces!
    assert_equal 2, svg.css(".voiced-staff").size
    assert_equal option[:voices].size, svg.css(".voiced-voice").size
    svg.css(".voiced-staff").each do |staff|
      assert_equal %w[down up], staff.css(".voiced-voice").map { |v| v["data-stem-direction"] }.sort
    end
    assert_equal before, option
  end

  test "new three voice scores use two treble voices and one bass without rejecting the previous format" do
    seen = nil
    20.times do |seed|
      e = VoicedDictationExerciseGenerator.new(level: 4, random: Random.new(seed)).call
      next unless e[:voice_count] == 3
      seen = e
      assert_equal "voices-v2", e[:dictation_format]
      assert_equal %w[treble treble bass], e[:options].first[:voices].map { |v| v[:clef] }
      assert ExerciseIntegrityValidator.validate!("percepcao", e)
      break
    end
    assert seen
  end

  test "legacy v1 music still validates and renders on at most two staves" do
    JSON.parse(File.read(Rails.root.join("test/support/legacy_voiced_dictation_v1.json"))).each do |payload|
      assert ExerciseIntegrityValidator.validate!("percepcao", payload)
      exercise = payload.deep_symbolize_keys
      svg = Nokogiri::XML(VoicedDictationSvgRenderer.new(voices: exercise[:options].first[:voices], total_steps: 32).call)
      svg.remove_namespaces!
      assert_operator svg.css(".voiced-staff").size, :<=, 2
    end
  end

  test "new wind dictations use a playable register and three or four voices require piano" do
    %w[flute clarinet].each do |instrument|
      e = VoicedDictationExerciseGenerator.new(level: 3, instrument:).call
      assert ExerciseIntegrityValidator.validate!("percepcao", e)
      assert e[:audio_events].all? { |event| MusicTheory::Note.parse(event[:pitch]).midi >= 60 }
      assert_equal %w[treble treble], e[:options].first[:voices].map { |v| v[:clef] }
      assert_raises(ArgumentError) { VoicedDictationExerciseGenerator.new(level: 4, instrument:) }
    end
  end
end
