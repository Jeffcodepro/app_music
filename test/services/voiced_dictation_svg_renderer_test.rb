require "test_helper"

class VoicedDictationSvgRendererTest < ActiveSupport::TestCase
  test "isolated sixteenths get partial secondary beams" do
    events = [1,2,1,4,4,4].each_with_object([]) do |duration, result|
      result << { pitch: "C4", start_step: result.sum { |e| e[:duration_steps] }, duration_steps: duration }
    end
    svg = Nokogiri::XML(VoicedDictationSvgRenderer.new(voices: [{ clef: "treble", events: }], total_steps: 16).call)
    svg.remove_namespaces!
    assert_equal 2, svg.css(".voiced-beam-secondary").size
    assert svg.css(".voiced-beam-secondary").all? { |l| (l["x2"].to_f-l["x1"].to_f).abs.between?(1,10) }
  end
  test "voices share staves with G4 and F3 clef anchors and aligned barlines" do
    e = VoicedDictationExerciseGenerator.new(level: 4, random: Random.new(0)).call
    option = e[:options].first
    layout = VoicedDictationSvgRenderer.layout_for(e[:options].map { |o| o[:voices] }, total_steps: e[:total_steps])
    svg = Nokogiri::XML(VoicedDictationSvgRenderer.new(voices: option[:voices], total_steps: e[:total_steps], layout:).call)
    svg.remove_namespaces!
    assert_equal 2, svg.css(".voiced-staff").size
    assert_operator svg.at_css("svg")["viewBox"].split.last.to_i, :<=, 416
    option[:voices].each_with_index do |voice, i|
      group = svg.at_css(".voiced-voice[data-voice-index='#{i}']")
      top = group.parent["data-top"].to_i
      clef = group.parent.at_css(".voiced-clef")
      assert_equal voice[:clef], clef["data-clef"]
      anchor = top + (voice[:clef] == "treble" ? 48 : 16)
      assert_includes clef["transform"], "translate(42 #{anchor})"
      notes = group.css(".voiced-note")
      assert_equal voice[:events].size, notes.size
      assert_in_delta layout[:x][0], notes.first["cx"].to_f, 0.01
      assert notes.all? { |n| n["cx"].to_f.between?(144, layout[:width]-24) }
      assert_equal top + { "C5" => 24, "C4" => 80, "C3" => 40, "C2" => 96 }.fetch(voice[:events].first[:pitch]), notes.first["cy"].to_i
    end
    assert svg.css(".voiced-beam-secondary").any?, "sixteenths need second beams"
    assert svg.css(".voiced-note").all? { |n| n["cy"].to_f.between?(6, svg.at_css("svg")["viewBox"].split.last.to_i-6) }
    assert svg.css(".voiced-stem").all? { |n| n["y2"].to_f.between?(6, svg.at_css("svg")["viewBox"].split.last.to_i-6) }
    e[:options].each do |o|
      other = Nokogiri::XML(VoicedDictationSvgRenderer.new(voices: o[:voices], total_steps: 32, layout:).call)
      assert_equal svg.at_css("svg")["viewBox"], other.root["viewBox"]
    end
  end
end
