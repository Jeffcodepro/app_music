require "test_helper"

class MelodicDictationTest < ActiveSupport::TestCase
  test "one voice produces four complete acoustically distinct scores with a common reference" do
    100.times do |seed|
      exercise = MelodicDictationExerciseGenerator.new(random: Random.new(seed)).call
      assert ExerciseIntegrityValidator.validate!("percepcao", exercise)
      assert_equal 4, exercise[:options].map { |o| o[:pitches] }.uniq.size
      assert exercise[:options].all? { |o| o[:pitches].size == 4 && o[:pitches].first == "C4" }
      assert_equal exercise[:options].find { |o| o[:id] == exercise[:correct_option_id] }[:pitches], exercise[:audio_sequence].flat_map { |n| n[:pitches] }
    end
  end

  test "independent validation rejects corrupted notes timing audio references and equivalent alternatives" do
    original = MelodicDictationExerciseGenerator.new(random: Random.new(1)).call
    mutations = [
      ->(e) { e[:options][0][:pitches][0] = "D4" },
      ->(e) { e[:options][1][:pitches] = e[:options][0][:pitches].dup },
      ->(e) { e[:audio_sequence][0][:frequencies][0] = 100 },
      ->(e) { e[:audio_sequence][0][:pitches][0] = "D4" },
      ->(e) { e[:audio_sequence].pop },
      ->(e) { e[:tempo_bpm] = 0 },
      ->(e) { e[:time_signature_label] = "6/8" },
      ->(e) { e[:duration_steps] = 8 },
      ->(e) { e[:correct_option_id] = "missing" },
      ->(e) { e[:options][0][:pitches][2] = "F#4" },
      ->(e) { e[:question] = "Escolha o acorde" },
      ->(e) { e[:options][0][:label] = "Outra" }
    ]
    mutations.each do |mutate|
      exercise = original.deep_dup
      mutate.call(exercise)
      assert_raises(ExerciseIntegrityValidator::Invalid) { ExerciseIntegrityValidator.validate!("percepcao", exercise) }
    end
  end

  test "natural notes have the reference staff coordinates and only C4 needs a ledger" do
    [[%w[C4 D4 E4 F4], [138, 130, 122, 114]], [%w[G4 A4 B4 C5], [106, 98, 90, 82]]].each do |pitches, expected_y|
      document = Nokogiri::XML(MelodicDictationSvgRenderer.new(pitches).call)
      assert_equal expected_y, document.css(".melody-note").map { |node| node["cy"].to_i }
    end
  end

  test "score renderer draws four quarter notes and a C4 ledger line without answer metadata" do
    svg = MelodicDictationSvgRenderer.new(%w[C4 D4 E4 C5]).call
    assert_equal 4, svg.scan('class="melody-note"').size
    assert_equal 1, svg.scan('class="melody-ledger"').size
    assert_equal 0, MelodicDictationSvgRenderer.new(%w[D4 D4 D4 D4]).call.scan('class="melody-ledger"').size
    refute_match(/correct|frequency|answer/, svg)
    assert_raises(ArgumentError) { MelodicDictationSvgRenderer.new(%w[C4 D4]).call }
  end

  test "treble clef origin aligns with G4 on the second staff line without a font baseline" do
    document = Nokogiri::XML(MelodicDictationSvgRenderer.new(%w[C4 E4 G4 C5]).call)
    clef = document.at_css(".melody-clef")
    assert clef, "The clef must have an explicit musical anchor"
    transform = clef["transform"].scan(/-?\d+(?:\.\d+)?/).map(&:to_f)
    assert_equal [44.0, 106.0], transform.first(2)
    assert_in_delta 16.0 / 360, transform[2], 0.000001
    assert_in_delta -16.0 / 360, transform[3], 0.000001
    assert_equal 106, document.css(".melody-note")[2]["cy"].to_i
    assert_equal 1, clef.css("path").size
    refute document.css("text").any? { |text| text.content.include?("𝄞") }, "Clef placement must not depend on an installed font"
  end
end
