require "erb"

class RhythmStaffSvgRenderer
  SVG_WIDTH = 460
  SVG_HEIGHT = 210
  STAFF_LEFT = 88
  STAFF_RIGHT = 430
  STAFF_TOP = 64
  STAFF_SPACING = 18
  NOTE_Y = STAFF_TOP + (2 * STAFF_SPACING)
  STEM_HEIGHT = 52
  NOTE_HEAD_RX = 13
  NOTE_HEAD_RY = 9
  CLEF_X = 42
  TIME_SIGNATURE_X = 66
  MEASURE_LEFT = 124
  MEASURE_RIGHT = 410
  REST_SYMBOLS = {
    4 => "𝄽",
    2 => "𝄾",
    1 => "𝄿"
  }.freeze

  def initialize(pattern_signature:)
    @pattern_signature = pattern_signature.to_s
    @tokens = RhythmExerciseGenerator.parse_pattern_signature(@pattern_signature)
    @events = build_events
  end

  def call
    <<~SVG
      <svg viewBox="0 0 #{SVG_WIDTH} #{SVG_HEIGHT}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="#{ERB::Util.html_escape(aria_label)}">
        <rect width="#{SVG_WIDTH}" height="#{SVG_HEIGHT}" rx="20" fill="#fcfbf8" />
        #{staff_lines_svg}
        #{barlines_svg}
        #{percussion_clef_svg}
        #{time_signature_svg}
        #{rests_svg}
        #{notes_svg}
        #{beams_svg}
      </svg>
    SVG
  end

  private

  def aria_label
    RhythmExerciseGenerator.pattern_aria_label(@tokens)
  end

  def build_events
    cursor = 0

    @tokens.map do |token|
      event = token.merge(start_step: cursor)
      cursor += token[:duration_steps]
      event
    end
  end

  def staff_lines_svg
    (0..4).map do |index|
      y = STAFF_TOP + (index * STAFF_SPACING)
      %(<line x1="#{STAFF_LEFT}" y1="#{y}" x2="#{STAFF_RIGHT}" y2="#{y}" stroke="#6b625d" stroke-width="2.2" stroke-linecap="round" />)
    end.join
  end

  def barlines_svg
    [
      %(<line x1="#{MEASURE_LEFT}" y1="#{STAFF_TOP}" x2="#{MEASURE_LEFT}" y2="#{STAFF_TOP + (4 * STAFF_SPACING)}" stroke="#6b625d" stroke-width="2.2" />),
      %(<line x1="#{MEASURE_RIGHT}" y1="#{STAFF_TOP}" x2="#{MEASURE_RIGHT}" y2="#{STAFF_TOP + (4 * STAFF_SPACING)}" stroke="#6b625d" stroke-width="2.8" />)
    ].join
  end

  def percussion_clef_svg
    <<~SVG.squish
      <g fill="#1c1917">
        <rect x="#{CLEF_X - 10}" y="#{NOTE_Y - 26}" width="7" height="52" rx="2" />
        <rect x="#{CLEF_X + 3}" y="#{NOTE_Y - 26}" width="7" height="52" rx="2" />
      </g>
    SVG
  end

  def time_signature_svg
    <<~SVG.squish
      <g fill="#1c1917" font-family="'Noto Serif', 'Times New Roman', serif" text-anchor="middle">
        <text x="#{TIME_SIGNATURE_X}" y="#{NOTE_Y - 16}" font-size="28" font-weight="700">4</text>
        <text x="#{TIME_SIGNATURE_X}" y="#{NOTE_Y + 22}" font-size="28" font-weight="700">4</text>
      </g>
    SVG
  end

  def rests_svg
    @events.filter { |event| event[:kind] == "rest" }.map do |event|
      symbol = REST_SYMBOLS[event[:duration_steps]]
      next "" if symbol.blank?

      %(
        <text x="#{event_x(event[:start_step])}"
              y="#{NOTE_Y + 6}"
              fill="#1c1917"
              font-size="30"
              font-family="'Noto Music', 'Bravura Text', 'Times New Roman', serif"
              text-anchor="middle"
              dominant-baseline="middle">#{symbol}</text>
      )
    end.join
  end

  def notes_svg
    @events.filter { |event| event[:kind] == "note" }.map do |event|
      stem_x = stem_x_for(event)
      stem_top_y = stem_top_y_for(event)
      beam_count = beam_count_for(event)
      stem_svg = if beam_count.zero?
                   %(<line x1="#{stem_x}" y1="#{NOTE_Y}" x2="#{stem_x}" y2="#{stem_top_y}" stroke="#1c1917" stroke-width="2.3" stroke-linecap="round" />)
                 else
                   %(<line x1="#{stem_x}" y1="#{NOTE_Y}" x2="#{stem_x}" y2="#{stem_top_y}" stroke="#1c1917" stroke-width="2.4" stroke-linecap="round" />)
                 end
      flag_svg = isolated_flag_svg(event)

      <<~SVG.squish
        <g fill="#1c1917" stroke="#1c1917" stroke-linecap="round">
          <ellipse cx="#{event_x(event[:start_step])}" cy="#{NOTE_Y}" rx="#{NOTE_HEAD_RX}" ry="#{NOTE_HEAD_RY}" transform="rotate(-18 #{event_x(event[:start_step])} #{NOTE_Y})" />
          #{stem_svg}
          #{flag_svg}
        </g>
      SVG
    end.join
  end

  def isolated_flag_svg(event)
    return "" unless isolated_beamed_note?(event)

    beam_count = beam_count_for(event)
    x = stem_x_for(event)
    y = stem_top_y_for(event)

    (0...beam_count).map do |index|
      offset = index * 8
      %(<path d="M #{x} #{y + offset} C #{x + 8} #{y + offset + 2}, #{x + 13} #{y + offset + 12}, #{x + 7} #{y + offset + 20}" fill="none" stroke="#1c1917" stroke-width="2.4" />)
    end.join
  end

  def beams_svg
    beam_groups.flat_map do |group|
      next [] if group.size < 2

      primary_beams = beam_segments_for(group, level: 1)
      secondary_beams = beam_segments_for(group, level: 2)
      primary_beams + secondary_beams
    end.join
  end

  def beam_segments_for(group, level:)
    beamable_events = group.select { |event| beam_count_for(event) >= level }
    return [] if beamable_events.size < 2

    segments = []
    beamable_events.each_cons(2) do |left, right|
      next unless contiguous_for_beam?(left, right)

      y = stem_top_y_for(left) + ((level - 1) * 8)
      segments << %(<line x1="#{stem_x_for(left)}" y1="#{y}" x2="#{stem_x_for(right)}" y2="#{y}" stroke="#1c1917" stroke-width="5.2" stroke-linecap="butt" />)
    end
    segments
  end

  def contiguous_for_beam?(left, right)
    right[:start_step] == left[:start_step] + left[:duration_steps]
  end

  def beam_groups
    @beam_groups ||= begin
      groups = []
      current_group = []

      @events.each do |event|
        if beamable_note?(event)
          if current_group.empty? || same_beat?(current_group.last, event) && contiguous_for_beam?(current_group.last, event)
            current_group << event
          else
            groups << current_group
            current_group = [event]
          end
        else
          groups << current_group if current_group.present?
          current_group = []
        end
      end

      groups << current_group if current_group.present?
      groups
    end
  end

  def same_beat?(left, right)
    beat_index(left[:start_step]) == beat_index(right[:start_step])
  end

  def beat_index(start_step)
    start_step / RhythmExerciseGenerator::STEPS_PER_BEAT
  end

  def beamable_note?(event)
    event[:kind] == "note" && beam_count_for(event).positive?
  end

  def isolated_beamed_note?(event)
    beamable_note?(event) && beam_groups.none? { |group| group.size > 1 && group.include?(event) }
  end

  def beam_count_for(event)
    return 0 if event[:kind] != "note"

    case event[:duration_steps]
    when 1 then 2
    when 2 then 1
    else 0
    end
  end

  def event_x(start_step)
    step_width = (MEASURE_RIGHT - MEASURE_LEFT).to_f / RhythmExerciseGenerator::TOTAL_STEPS
    MEASURE_LEFT + (start_step * step_width) + (step_width / 2.0)
  end

  def stem_x_for(event)
    event_x(event[:start_step]) + 10
  end

  def stem_top_y_for(_event)
    NOTE_Y - STEM_HEIGHT
  end
end
