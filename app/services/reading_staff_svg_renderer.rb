require "erb"

class ReadingStaffSvgRenderer
  STAFF_LEFT = 58
  STAFF_RIGHT = 430
  STAFF_TOP = 68
  STAFF_SPACING = 18
  NOTE_X = 286
  CLEF_X = 84
  NOTE_HEAD_RX = 16
  NOTE_HEAD_RY = 11
  STEM_HEIGHT = 58
  SVG_WIDTH = 460
  SVG_HEIGHT = 210
  CLEF_LAYOUTS = {
    "treble" => { symbol: "𝄞", font_size: 138, anchor_offset_y: -2 },
    "bass" => { symbol: "𝄢", font_size: 118, anchor_offset_y: 28 },
    "alto" => { symbol: "𝄡", font_size: 100, anchor_offset_y: 10 }
  }.freeze
  ACCIDENTAL_X = NOTE_X - 32
  KEY_SIGNATURE_START_X = 148
  KEY_SIGNATURE_SPACING = 24

  def initialize(exercise:)
    @exercise = exercise
  end

  def call
    <<~SVG
      <svg viewBox="0 0 #{SVG_WIDTH} #{SVG_HEIGHT}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="#{ERB::Util.html_escape(@exercise[:pitch_label])} em #{ERB::Util.html_escape(@exercise[:clef_label])}">
        <rect width="#{SVG_WIDTH}" height="#{SVG_HEIGHT}" rx="20" fill="#fcfbf8" />
        #{staff_lines_svg}
        #{ledger_lines_svg}
        #{clef_svg}
        #{notation_symbols_svg}
        #{note_svg}
      </svg>
    SVG
  end

  private

  def staff_lines_svg
    (1..5).map do |line_number|
      %(<line x1="#{STAFF_LEFT}" y1="#{line_y(line_number)}" x2="#{STAFF_RIGHT}" y2="#{line_y(line_number)}" stroke="#5a524d" stroke-width="2.4" stroke-linecap="round" />)
    end.join
  end

  def ledger_lines_svg
    ledger_positions.map do |staff_position_index|
      %(<line x1="#{NOTE_X - 26}" y1="#{staff_position_y(staff_position_index)}" x2="#{NOTE_X + 26}" y2="#{staff_position_y(staff_position_index)}" stroke="#5a524d" stroke-width="2.4" stroke-linecap="round" />)
    end.join
  end

  def clef_svg
    text_clef_svg
  end

  def text_clef_svg
    layout = CLEF_LAYOUTS.fetch(@exercise[:clef_id])

    %(
      <text x="#{CLEF_X}"
            y="#{clef_anchor_y(layout)}"
            fill="#1c1917"
            font-size="#{layout[:font_size]}"
            font-family="'Noto Music', 'Bravura Text', 'Times New Roman', serif"
            text-anchor="middle"
            dominant-baseline="middle">#{layout[:symbol]}</text>
    )
  end

  def notation_symbols_svg
    [key_signature_svg, note_accidental_svg].join
  end

  def key_signature_svg
    accidentals = Array(@exercise[:key_signature_accidentals])
    return "" if accidentals.empty?

    accidentals.each_with_index.map do |accidental, index|
      accidental_text_svg(
        symbol: accidental[:symbol],
        x: KEY_SIGNATURE_START_X + (index * KEY_SIGNATURE_SPACING),
        y: staff_position_y(accidental[:staff_position_index])
      )
    end.join
  end

  def note_accidental_svg
    return "" if @exercise[:note_accidental_symbol].blank? || @exercise[:notation_kind] == "key_signature"

    accidental_text_svg(
      symbol: @exercise[:note_accidental_symbol],
      x: ACCIDENTAL_X,
      y: staff_position_y(@exercise[:staff_position_index])
    )
  end

  def accidental_text_svg(symbol:, x:, y:)
    %(
      <text x="#{x}"
            y="#{y}"
            fill="#1c1917"
            font-size="32"
            font-family="'Noto Music', 'Bravura Text', 'Times New Roman', serif"
            text-anchor="middle"
            dominant-baseline="middle">#{symbol}</text>
    )
  end

  def note_svg
    return "" if @exercise[:notation_kind] == "key_signature"

    y = staff_position_y(@exercise[:staff_position_index])
    if stem_down?
      %(
        <g fill="#1c1917" stroke="#1c1917" stroke-linecap="round">
          <ellipse cx="#{NOTE_X}" cy="#{y}" rx="#{NOTE_HEAD_RX}" ry="#{NOTE_HEAD_RY}" transform="rotate(-18 #{NOTE_X} #{y})" />
          <line x1="#{NOTE_X - 11}" y1="#{y}" x2="#{NOTE_X - 11}" y2="#{y + STEM_HEIGHT}" stroke-width="2.6" />
        </g>
      )
    else
      %(
        <g fill="#1c1917" stroke="#1c1917" stroke-linecap="round">
          <ellipse cx="#{NOTE_X}" cy="#{y}" rx="#{NOTE_HEAD_RX}" ry="#{NOTE_HEAD_RY}" transform="rotate(-18 #{NOTE_X} #{y})" />
          <line x1="#{NOTE_X + 11}" y1="#{y}" x2="#{NOTE_X + 11}" y2="#{y - STEM_HEIGHT}" stroke-width="2.6" />
        </g>
      )
    end
  end

  def ledger_positions
    position = @exercise[:staff_position_index].to_i
    return [] if position.between?(0, 8)

    if position.negative?
      (-2).step(position, -2).to_a
    else
      10.step(position, 2).to_a.reverse
    end
  end

  def stem_down?
    @exercise[:staff_position_index].to_i >= 5
  end

  def clef_anchor_y(layout)
    line_y(clef.line) + layout[:anchor_offset_y]
  end

  def clef
    @clef ||= HeadMusic::Rudiment::Clef.get(@exercise[:head_music_clef])
  end

  def line_y(line_number)
    STAFF_TOP + ((5 - line_number) * STAFF_SPACING)
  end

  def staff_position_y(staff_position_index)
    if staff_position_index.even?
      line_y((staff_position_index / 2) + 1)
    else
      lower_line = line_y(((staff_position_index - 1) / 2) + 1)
      lower_line - (STAFF_SPACING / 2.0)
    end
  end
end
