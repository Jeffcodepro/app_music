require "test_helper"

class RhythmStaffSvgRendererTest < ActiveSupport::TestCase
  test "rests remain visible without relying on installed music fonts" do
    svg = Nokogiri::XML(RhythmStaffSvgRenderer.new(pattern_signature: "r4.r2.r1.n1.n4.n4").call)
    [4, 2, 1].each { |duration| assert_equal 1, svg.css("g[data-rest-duration='#{duration}'] path").length }
    refute_match(/[𝄽𝄾𝄿]/, svg.to_xml)
  end

  test "dense sixteenth notes have separate proportional heads and attached stems" do
    svg = Nokogiri::XML(RhythmStaffSvgRenderer.new(pattern_signature: Array.new(16, "n1").join(".")).call)
    heads = svg.css("ellipse")
    assert_equal 16, heads.length
    heads.each_cons(2) do |left, right|
      assert_operator right["cx"].to_f - left["cx"].to_f, :>=, left["rx"].to_f + right["rx"].to_f + 2
    end
    heads.each do |head|
      assert_in_delta 13.0 / 9, head["rx"].to_f / head["ry"].to_f
      assert_operator (head.parent.at_css("line")["x1"].to_f - head["cx"].to_f).abs, :<, head["rx"].to_f
    end
  end

  test "compact canvas preserves staff, stems, beams and rests at their original coordinates" do
    ["n4.n4.n4.n4", "n2.n2.n2.n2.n2.n2.n2.n2", "r2.n1.n1.n4.n4.n4"].each do |pattern|
      svg = Nokogiri::XML(RhythmStaffSvgRenderer.new(pattern_signature: pattern).call)
      assert_equal "0 28 460 128", svg.at_css("svg")["viewBox"]
      assert svg.at_css("svg")["aria-label"].present?
      svg.css("line").each do |line|
        ["y1", "y2"].each { |key| assert_operator line[key].to_f, :>=, 30; assert_operator line[key].to_f, :<=, 154 }
      end
      svg.css("ellipse").each { |note| assert_equal 100, note["cy"].to_f }
    end
  end
end

class MetricalRhythmStaffSvgRendererTest < ActiveSupport::TestCase
  test "new notation shows the real formula dots open heads and internal bars" do
    meter = MusicTheory::Meter.fetch("2-2")
    svg = Nokogiri::XML(RhythmStaffSvgRenderer.new(pattern_signature: "n8.r8.n8.n8", meter:, measure_count: 2).call)
    assert_equal %w[2 2], svg.css("text").map(&:text)
    assert_equal 3, svg.css('ellipse[fill="#fcfbf8"]').size
    assert_equal 1, svg.css('[data-rest-duration="8"] rect').size
    assert_equal 1, svg.css('[data-measure-boundary="1"]').size
    dotted = Nokogiri::XML(RhythmStaffSvgRenderer.new(pattern_signature: "n6.r6", meter: MusicTheory::Meter.fetch("6-8")).call)
    assert_equal 2, dotted.css('[data-augmentation-dot]').size
  end

  test "compound beams follow groups and isolated sixteenths retain their secondary hooks" do
    svg = Nokogiri::XML(RhythmStaffSvgRenderer.new(pattern_signature: "n1.n2.n1.n4.n4.n4").call)
    assert_equal 2, svg.css('[data-partial-beam]').size
    compound = Nokogiri::XML(RhythmStaffSvgRenderer.new(pattern_signature: Array.new(6, "n2").join('.'), meter: MusicTheory::Meter.fetch("6-8")).call)
    # Two groups of three eighths: four primary connections, never five.
    assert_equal 4, compound.css('line[stroke-width="5.2"]').size
  end
  test "dense metrical notation preserves full note heads with spacing and bar margins" do
    pattern = Array.new(4, "n1.n1.n2.n4.n4").join('.')
    svg = Nokogiri::XML(RhythmStaffSvgRenderer.new(pattern_signature: pattern, meter: MusicTheory::Meter.fetch("12-4")).call)
    heads = svg.css('ellipse')
    heads.each { |head| assert_equal 13, head['rx'].to_f }
    heads.each_cons(2) { |a,b| assert_operator b['cx'].to_f - a['cx'].to_f, :>=, 29 }
    assert_operator heads.first['cx'].to_f - heads.first['rx'].to_f, :>, 124
  end

end
