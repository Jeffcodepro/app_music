require "erb"

class RhythmStaffSvgRenderer
  SVG_WIDTH = 460
  SVG_TOP = 28
  SVG_HEIGHT = 128
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
  # Bravura outlines copyright © Steinberg Media Technologies GmbH, OFL-1.1.
  # These derived AppMusic rest drawings retain OFL-1.1; docs/licenses/rhythm-rests.md.
  REST_GLYPHS = {
    4 => { width: 389, path: "M 112 -55 C 135 -84 156 -111 174 -141 C 177 -147 183 -158 183 -161 C 183 -163 183 -166 181 -167 C 179 -173 173 -174 166 -174 C 160 -174 148 -171 143 -170 C 141 -170 138 -170 137 -170 L 125 -166 C 50 -166 1 -233 1 -304 C 1 -376 63 -446 168 -527 C 180 -536 194 -540 206 -540 C 216 -540 226 -537 228 -531 C 229 -527 230 -524 230 -521 C 230 -508 219 -497 207 -487 C 189 -487 173 -448 170 -435 C 166 -423 164 -410 164 -397 C 164 -338 194 -292 255 -292 C 297 -292 344 -308 369 -317 L 370 -318 C 376 -320 379 -320 382 -320 C 386 -320 389 -318 389 -314 C 389 -297 351 -249 336 -232 C 281 -166 236 -112 236 -32 C 236 -30 236 -29 236 -27 L 238 -17 C 238 -16 238 -14 238 -13 C 243 71 295 140 333 199 C 337 206 338 213 338 220 C 338 235 333 248 333 248 C 333 248 120 501 95 526 C 88 533 78 537 69 537 C 55 537 40 527 40 507 C 40 500 42 492 46 484 C 52 468 134 395 134 291 C 134 238 112 176 48 108 C 33 94 27 78 27 66 C 27 46 42 32 42 32 Z" }.freeze,
    2 => { width: 356, path: "M 193 154 C 193 207 150 251 96 251 C 43 251 0 207 0 154 C 0 124 17 98 39 81 C 62 65 89 56 117 56 C 137 56 157 60 173 66 C 193 72 206 78 225 88 C 228 89 230 89 232 89 C 238 89 239 84 239 76 C 239 72 239 66 238 60 C 233 39 130 -248 104 -343 C 104 -360 137 -361 145 -361 C 161 -361 181 -359 196 -347 C 200 -344 341 161 341 161 C 347 187 354 210 356 217 C 356 232 341 239 338 240 C 336 240 331 240 323 235 C 312 226 240 140 193 140 Z" }.freeze,
    1 => { width: 461, path: "M 300 160 C 300 215 256 258 202 258 C 148 258 104 215 104 160 C 104 101 164 62 219 62 C 258 62 298 75 331 94 C 336 95 338 96 341 96 C 346 96 348 94 348 86 C 348 63 275 -151 265 -173 C 253 -200 215 -217 194 -217 C 196 -212 196 -207 196 -203 C 196 -148 151 -105 98 -105 C 43 -105 0 -148 0 -203 C 0 -262 60 -301 115 -301 C 153 -301 190 -288 223 -271 C 226 -271 229 -274 229 -279 L 228 -281 C 228 -282 228 -282 228 -282 L 91 -690 C 91 -690 91 -691 91 -691 L 89 -693 C 89 -706 102 -720 134 -720 C 176 -720 183 -703 189 -687 L 356 -138 C 393 -16 420 81 420 81 C 420 81 456 207 459 226 C 459 229 461 230 461 232 C 461 240 449 246 446 248 C 439 248 435 245 431 242 C 420 233 348 147 300 145 Z" }.freeze,
  }.freeze

  def initialize(pattern_signature:, meter: nil, measure_count: 1)
    @meter, @measure_count = meter, measure_count
    @pattern_signature = pattern_signature.to_s
    @tokens = meter ? MetricalRhythmExerciseGenerator.tokens(@pattern_signature) : RhythmExerciseGenerator.parse_pattern_signature(@pattern_signature)
    @events = build_events
    if meter && (!measure_count.is_a?(Integer) || !(1..2).cover?(measure_count) || @tokens.sum { |t| t[:duration_steps] } != total_steps)
      raise RhythmExerciseGenerator::InvalidPattern, "incomplete_measure"
    end
  end

  def call
    <<~SVG
      <svg viewBox="0 #{SVG_TOP} #{svg_width} #{SVG_HEIGHT}" #{score_style} xmlns="http://www.w3.org/2000/svg" role="img" aria-label="#{ERB::Util.html_escape(aria_label)}">
        <rect y="#{SVG_TOP}" width="#{svg_width}" height="#{SVG_HEIGHT}" rx="20" fill="#fcfbf8" />
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
    return RhythmExerciseGenerator.pattern_aria_label(@tokens) unless @meter
    "#{@meter.option_label}, #{@measure_count} #{@measure_count == 1 ? 'compasso' : 'compassos'}: #{MetricalRhythmExerciseGenerator.option(@pattern_signature)[:aria_label]}"
  end

  def total_steps = @meter ? @meter.measure_steps * @measure_count : RhythmExerciseGenerator::TOTAL_STEPS
  def svg_width = @meter ? metrical_layout[:right] + 50 : SVG_WIDTH
  def measure_right = @meter ? metrical_layout[:right] : MEASURE_RIGHT
  def staff_right = @meter ? svg_width - 30 : STAFF_RIGHT
  def score_style = @meter && svg_width > 560 ? %(style="min-width:#{(svg_width * 0.7).round}px") : ""


  # Musical engraving is not a linear time axis. Reserve readable space per
  # figure, keeping durations in the notation/audio contract rather than shrinking
  # every head when one dense group appears beside a long note.
  def metrical_layout
    @metrical_layout ||= begin
      x = MEASURE_LEFT.to_f; positions = {}; boundaries = [x]
      @measure_count.times do |bar|
        x += 20
        @events.select { |event| event[:start_step] / @meter.measure_steps == bar }.each do |event|
          positions[event[:start_step]] = x
          x += [34, Math.sqrt(event[:duration_steps]) * 22].max
        end
        x += 16; boundaries << x
      end
      factor = [1.0, (MEASURE_RIGHT - MEASURE_LEFT) / (x - MEASURE_LEFT)].max
      positions.transform_values! { |value| MEASURE_LEFT + (value - MEASURE_LEFT) * factor }
      boundaries.map! { |value| MEASURE_LEFT + (value - MEASURE_LEFT) * factor }
      { positions:, boundaries:, right: boundaries.last.ceil }
    end
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
      %(<line x1="#{STAFF_LEFT}" y1="#{y}" x2="#{staff_right}" y2="#{y}" stroke="#6b625d" stroke-width="2.2" stroke-linecap="round" />)
    end.join
  end

  def barlines_svg
    internal = @meter ? (1...@measure_count).map do |bar|
      x = metrical_layout[:boundaries].fetch(bar)
      %(<line data-measure-boundary="#{bar}" x1="#{x}" y1="#{STAFF_TOP}" x2="#{x}" y2="#{STAFF_TOP + 4 * STAFF_SPACING}" stroke="#6b625d" stroke-width="2.2" />)
    end.join : ""
    internal + [
      %(<line x1="#{MEASURE_LEFT}" y1="#{STAFF_TOP}" x2="#{MEASURE_LEFT}" y2="#{STAFF_TOP + (4 * STAFF_SPACING)}" stroke="#6b625d" stroke-width="2.2" />),
      %(<line x1="#{measure_right}" y1="#{STAFF_TOP}" x2="#{measure_right}" y2="#{STAFF_TOP + (4 * STAFF_SPACING)}" stroke="#6b625d" stroke-width="2.8" />)
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
        <text x="#{TIME_SIGNATURE_X}" y="#{NOTE_Y - 16}" font-size="28" font-weight="700">#{@meter ? @meter.numerator : 4}</text>
        <text x="#{TIME_SIGNATURE_X}" y="#{NOTE_Y + 22}" font-size="28" font-weight="700">#{@meter ? @meter.denominator : 4}</text>
      </g>
    SVG
  end

  def rests_svg
    step_width = (measure_right - MEASURE_LEFT).to_f / total_steps
    @events.filter { |event| event[:kind] == "rest" }.map do |event|
      duration = event[:duration_steps]
      base = { 3 => 2, 6 => 4, 12 => 8 }.fetch(duration, duration)
      center = event_x(event[:start_step])
      dot = [3, 6, 12].include?(duration) ? %(<circle data-augmentation-dot="true" cx="#{center + 14}" cy="#{NOTE_Y - 5}" r="2.5" fill="#1c1917"/>) : ""
      if base >= 8
        y = base == 8 ? NOTE_Y - 6 : STAFF_TOP + STAFF_SPACING
        %(<g data-rest-duration="#{duration}"><rect x="#{center - 9}" y="#{y}" width="18" height="6" fill="#1c1917"/>#{dot}</g>)
      else
        glyph = REST_GLYPHS.fetch(base)
        scale = [0.045, ((duration * step_width) - 3) / glyph[:width]].min
        x = center - (glyph[:width] * scale / 2)
        %(<g data-rest-duration="#{duration}" transform="translate(#{x} #{NOTE_Y}) scale(#{scale} #{-scale})" fill="#1c1917"><path d="#{glyph[:path]}" /></g>) + dot
      end
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
      stem_svg = "" if event[:duration_steps] == 16
      flag_svg = isolated_flag_svg(event)
      open_head = [8, 12, 16].include?(event[:duration_steps])
      head_style = open_head ? ' fill="#fcfbf8" stroke="#1c1917" stroke-width="2"' : ''
      dot = [3, 6, 12].include?(event[:duration_steps]) ? %(<circle data-augmentation-dot="true" cx="#{event_x(event[:start_step]) + 17 * note_head_scale}" cy="#{NOTE_Y - 5}" r="2.5" fill="#1c1917"/>) : ""

      <<~SVG.squish
        <g fill="#1c1917" stroke="#1c1917" stroke-linecap="round">
          <ellipse cx="#{event_x(event[:start_step])}" cy="#{NOTE_Y}" rx="#{NOTE_HEAD_RX * note_head_scale}" ry="#{NOTE_HEAD_RY * note_head_scale}" transform="rotate(-18 #{event_x(event[:start_step])} #{NOTE_Y})"#{head_style} />
          #{stem_svg}
          #{flag_svg}
          #{dot}
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
      partials = group.filter { |event| beam_count_for(event) == 2 }.filter_map do |event|
        connected = group.any? { |other| other != event && beam_count_for(other) == 2 && (contiguous_for_beam?(event, other) || contiguous_for_beam?(other, event)) }
        next if connected
        direction = event == group.last ? -1 : 1
        x = stem_x_for(event); y = stem_top_y_for(event) + 8
        %(<line data-partial-beam="true" x1="#{x}" y1="#{y}" x2="#{x + direction * 8}" y2="#{y}" stroke="#1c1917" stroke-width="5.2" stroke-linecap="butt" />)
      end
      primary_beams + secondary_beams + partials
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
    return start_step / RhythmExerciseGenerator::STEPS_PER_BEAT unless @meter
    bar, offset = start_step.divmod(@meter.measure_steps)
    bar * @meter.groups.size + @meter.group_starts.rindex { |start| start <= offset }
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
    when 2, 3 then 1
    else 0
    end
  end

  def event_x(start_step)
    return metrical_layout[:positions].fetch(start_step) if @meter
    step_width = (measure_right - MEASURE_LEFT).to_f / total_steps
    MEASURE_LEFT + (start_step * step_width) + (step_width / 2.0)
  end

  # Preserve event centers and aspect ratio; avoid head collisions only when
  # adjacent attacks are closer than a normal note head plus breathing room.
  def note_head_scale
    return 1.0 if @meter
    @note_head_scale ||= begin
      positions = @events.select { |event| event[:kind] == "note" }.map { |event| event_x(event[:start_step]) }
      spacing = positions.each_cons(2).map { |left, right| right - left }.min || Float::INFINITY
      [1.0, (spacing - 3) / (2 * NOTE_HEAD_RX)].min
    end
  end

  def stem_x_for(event)
    event_x(event[:start_step]) + (10 * note_head_scale)
  end

  def stem_top_y_for(_event)
    NOTE_Y - STEM_HEIGHT
  end
end
