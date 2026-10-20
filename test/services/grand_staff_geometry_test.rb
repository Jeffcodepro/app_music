require "test_helper"

class GrandStaffGeometryTest < ActiveSupport::TestCase
  def events(pitches, durations)
    cursor = 0
    pitches.zip(durations).map do |pitch, duration|
      event = { pitch:, start_step: cursor, duration_steps: duration }
      cursor += duration
      event
    end
  end

  test "opposed stems fit B5 and C2 and simultaneous seconds leave room for the next sixteenth" do
    # Engraving boundary fixture, not a candidate issued by the exercise generator.
    voices = [
      { clef: "treble", events: events(%w[C5 B5 C5 B5], [4]*4) },
      { clef: "treble", events: events(%w[B4 A4 G4 E4 G4 E4], [1,1,2,4,4,4]) },
      { clef: "bass", events: events(%w[B3 C3 B3 C3], [4]*4) },
      { clef: "bass", events: events(%w[C2 E2 C2 E2], [4]*4) }
    ]
    svg = Nokogiri::XML(VoicedDictationSvgRenderer.new(voices:, total_steps: 16).call)
    svg.remove_namespaces!
    height = svg.root["viewBox"].split.last.to_i
    assert svg.css(".voiced-stem, .voiced-beam, .voiced-beam-secondary").all? { |n| [n["y1"].to_f,n["y2"].to_f].all? { |y| y.between?(6,height-6) } }
    svg.css(".voiced-staff").each do |staff|
      staff.css(".voiced-note").to_a.combination(2).each do |a,b|
        next unless (a["cy"].to_f-b["cy"].to_f).abs < 12
        assert_operator (a["cx"].to_f-b["cx"].to_f).abs, :>=, 18
      end
    end
    upper = svg.css(".voiced-staff")[0].css(".voiced-stem").map { |n| [n["y1"].to_f,n["y2"].to_f].max }.max
    lower = svg.css(".voiced-staff")[1].css(".voiced-stem").map { |n| [n["y1"].to_f,n["y2"].to_f].min }.min
    assert_operator lower-upper, :>=, 24
  end
end
