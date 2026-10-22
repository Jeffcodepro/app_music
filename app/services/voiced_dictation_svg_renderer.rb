class VoicedDictationSvgRenderer
  # AppMusic drawing derived from Bravura fClef, OFL-1.1. Same source and
  # conversion as docs/licenses/treble-clef.md; origin lies on the F3 line.
  BASS_CLEF_PATH = "M 363 377 C 112 377 0 194 0 56 C 0 -59 60 -158 177 -158 C 268 -158 330 -95 330 -6 C 330 86 262 144 192 144 C 153 144 138 134 120 134 C 101 134 96 145 96 160 C 96 217 183 323 330 323 C 482 323 549 173 549 -53 C 549 -455 350 -680 14 -871 C 1 -878 -7 -886 -7 -897 C -7 -906 -1 -914 12 -914 C 19 -914 27 -912 36 -907 C 390 -734 765 -478 765 -40 C 765 210 612 377 363 377 Z M 906 259 C 861 259 827 225 827 180 C 827 135 861 101 906 101 C 950 101 985 135 985 180 C 985 225 950 259 906 259 Z M 907 -102 C 863 -102 829 -135 829 -180 C 829 -225 863 -258 907 -258 C 952 -258 985 -225 985 -180 C 985 -135 952 -102 907 -102 Z".freeze
  # All alternatives share a layout, including space for displaced seconds.
  def self.layout_for(voice_sets, total_steps:)
    raise ArgumentError, "invalid meter" unless [16, 32].include?(total_steps)
    displaced = Array.new(total_steps, 0)
    voice_sets.each do |voices|
      voices.group_by { |v| v.fetch(:clef) }.each_value do |lines|
        next unless lines.size == 2
        first = lines[0].fetch(:events).index_by { |e| e.fetch(:start_step) }
        lines[1].fetch(:events).each do |e|
          other = first[e.fetch(:start_step)]
          next unless other
          distance = (MusicTheory::Note.parse(other.fetch(:pitch)).diatonic_index - MusicTheory::Note.parse(e.fetch(:pitch)).diatonic_index).abs
          displaced[e[:start_step]] = 10 if distance <= 1
        end
      end
    end
    positions = []
    bars = []
    cursor = 144.0
    total_steps.times do |step|
      if (step % 16).zero?
        bars << cursor
        cursor += 30
      end
      positions << cursor
      gap = [22, 22 + displaced[step] + (displaced[step + 1] || 0)].max
      cursor += gap
    end
    bars << cursor + 10
    { x: positions, bars:, width: (bars.last + 24).ceil }
  end

  def initialize(voices:, total_steps:, layout: nil)
    raise ArgumentError, "invalid score" unless voices.is_a?(Array) && (1..4).cover?(voices.size) && [16,32].include?(total_steps)
    @voices, @total = voices, total_steps
    @staves = %w[treble bass].filter_map do |clef|
      lines = voices.select { |v| v.fetch(:clef) == clef }
      next if lines.empty?
      raise ArgumentError, "too many voices on one staff" if lines.size > 2
      [clef, lines]
    end
    raise ArgumentError, "invalid clef" unless @staves.sum { |_, lines| lines.size } == voices.size
    @layout = layout || self.class.layout_for([voices], total_steps:)
    @width = @layout.fetch(:width)
  end

  def call
    cursor = 16
    tops = []
    staff_markup = @staves.each_with_index.map do |(clef, lines), index|
      lower, upper = lines.size == 1 ? [-28, 110] : (clef == "treble" ? [-60, 116] : [-44, 132])
      top = cursor - lower
      tops << top
      cursor = top + upper + 32
      staff(clef, lines, top, index)
    end.join
    height = cursor - 16
    connector = tops.size == 2 ? %(<line class="voiced-system" x1="24" x2="24" y1="#{tops.first}" y2="#{tops.last+64}" stroke="currentColor" stroke-width="2"/>) : ""
    %(<svg class="voiced-score" viewBox="0 0 #{@width} #{height}" style="min-width:#{(@width * 0.7).round}px" role="img" aria-label="Partitura de #{@voices.size} vozes em #{@staves.size} pautas, #{@total/16} compassos em 4/4" xmlns="http://www.w3.org/2000/svg">#{connector}#{staff_markup}</svg>).html_safe
  end

  private

  def staff(clef, voices, top, staff_index)
    bottom = top + 64
    base = clef == "treble" ? 30 : 18
    path = clef == "treble" ? MelodicDictationSvgRenderer::TREBLE_CLEF_PATH : BASS_CLEF_PATH
    anchor = top + (clef == "treble" ? 48 : 16)
    lines = 5.times.map { |i| %(<line x1="24" y1="#{top+i*16}" x2="#{@width-24}" y2="#{top+i*16}"/>) }.join
    bars = @layout.fetch(:bars).map { |x| %(<line x1="#{x}" y1="#{top}" x2="#{x}" y2="#{bottom}"/>) }.join
    voice_events = voices.map do |voice|
      voice.fetch(:events).map do |event|
        note = MusicTheory::Note.parse(event.fetch(:pitch))
        start = event.fetch(:start_step); duration = event.fetch(:duration_steps)
        valid = start.is_a?(Integer) && duration.is_a?(Integer) && start >= 0 && start+duration <= @total && [1,2,4].include?(duration)
        valid &&= (clef == "treble" ? (4..5) : (2..3)).cover?(note.octave)
        raise ArgumentError, "invalid note" unless valid
        event.merge(x: @layout.fetch(:x).fetch(start), y: bottom-(note.diatonic_index-base)*8)
      end
    end
    if voices.size == 2
      voice_events[0].each do |upper|
        lower = voice_events[1].find { |event| event[:start_step] == upper[:start_step] }
        next unless lower && (upper[:y]-lower[:y]).abs <= 8
        upper[:x] += 10
        lower[:x] -= 10
      end
    end
    ledgers = Hash.new { |hash, key| hash[key] = [] }
    voices_markup = voice_events.each_with_index.map do |events, voice_index|
      direction = voices.size == 2 ? (voice_index.zero? ? "up" : "down") : "auto"
      notes = events.map do |event|
        if event[:y] >= bottom + 16
          (bottom+16).step(event[:y],16) { |y| ledgers[y] << [event[:x]-13, event[:x]+13] }
        elsif event[:y] <= top - 16
          (top-16).step(event[:y],-16) { |y| ledgers[y] << [event[:x]-13, event[:x]+13] }
        end
        %(<ellipse class="voiced-note" data-step="#{event[:start_step]}" data-duration="#{event[:duration_steps]}" cx="#{event[:x]}" cy="#{event[:y]}" rx="9" ry="6" transform="rotate(-18 #{event[:x]} #{event[:y]})" stroke="none" fill="currentColor"/>)
      end.join
      stems = events.group_by { |event| event[:start_step]/4 }.values.map { |group| stems(group, top, direction) }.join
      %(<g class="voiced-voice" data-voice-index="#{@voices.index(voices[voice_index])}" data-stem-direction="#{direction}">#{notes}#{stems}</g>)
    end.join
    ledger_markup = ledgers.flat_map do |y, segments|
      merged = []
      segments.sort.each do |left, right|
        if merged.last && left <= merged.last[1]
          merged.last[1] = [merged.last[1], right].max
        else
          merged << [left, right]
        end
      end
      merged.map { |left,right| %(<line class="voiced-ledger" x1="#{left}" x2="#{right}" y1="#{y}" y2="#{y}"/>) }
    end.join
    %(<g class="voiced-staff" data-staff-index="#{staff_index}" data-clef="#{clef}" data-top="#{top}" stroke="currentColor" stroke-width="1.8">#{lines}#{bars}#{ledger_markup}#{voices_markup}<g class="voiced-clef" data-clef="#{clef}" transform="translate(42 #{anchor}) scale(#{16.0/360} #{-16.0/360})" fill="currentColor" stroke="none"><path d="#{path}"/></g><g fill="currentColor" stroke="none" font-family="serif" font-size="30" font-weight="bold" text-anchor="middle"><text x="116" y="#{top+25}">4</text><text x="116" y="#{top+57}">4</text></g></g>)
  end

  def stems(group, top, direction)
    up = direction == "auto" ? group.sum { |e| e[:y] } / group.size > top + 32 : direction == "up"
    beam_y = up ? group.map { |e| e[:y] }.min - 36 : group.map { |e| e[:y] }.max + 36
    sx = ->(e) { e[:x] + (up ? 7 : -7) }
    drawing = group.map { |e| %(<line class="voiced-stem" x1="#{sx.call(e)}" x2="#{sx.call(e)}" y1="#{e[:y]}" y2="#{beam_y}"/>) }.join
    return drawing unless group.size > 1
    drawing += %(<line class="voiced-beam" x1="#{sx.call(group.first)}" x2="#{sx.call(group.last)}" y1="#{beam_y}" y2="#{beam_y}" stroke-width="4"/>)
    group.each_with_index do |e,i|
      next unless e[:duration_steps] == 1
      y = beam_y + (up ? 7 : -7)
      if i+1 < group.size && group[i+1][:duration_steps] == 1
        finish = sx.call(group[i+1])
      elsif i.positive? && group[i-1][:duration_steps] == 1
        next
      else
        neighbour = i == group.size-1 ? group[i-1] : group[i+1]
        length = [10, (sx.call(neighbour)-sx.call(e)).abs * 0.4].min
        finish = sx.call(e) + (i == group.size-1 ? -length : length)
      end
      drawing += %(<line class="voiced-beam-secondary" x1="#{sx.call(e)}" x2="#{finish}" y1="#{y}" y2="#{y}" stroke-width="4"/>)
    end
    drawing
  end
end
