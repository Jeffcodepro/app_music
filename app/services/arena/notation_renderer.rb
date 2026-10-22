module Arena
  # New snapshots only. Staff coordinates express the existing exercise exactly.
  class NotationRenderer
    TOP = 62
    SPACE = 14
    BOTTOM = TOP + 4 * SPACE
    NOTE_X = 266
    def initialize(exercise:)
      @exercise = exercise.deep_symbolize_keys
    end

    def call
      key = @exercise[:notation_kind] == "key_signature"
      note_y = key ? BOTTOM : y(@exercise.fetch(:staff_position_index))
      top = [0,note_y - 58].min
      bottom = [176,note_y + 58].max
      lines = 5.times.map { |i| %(<line x1="28" y1="#{TOP + i * SPACE}" x2="390" y2="#{TOP + i * SPACE}"/>) }.join
      %(<svg data-arena-notation="v2" viewBox="0 #{top} 420 #{bottom - top}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Partitura em #{ERB::Util.html_escape(@exercise.fetch(:clef_label))}"><g fill="none" stroke="currentColor" stroke-width="1.2">#{lines}#{ledgers unless key}</g>#{clef}#{symbols}#{note unless key}</svg>)
    end

    private

    def y(index) = BOTTOM - index * SPACE / 2.0
    def clef
      scale = SPACE / 360.0
      case @exercise.fetch(:clef_id)
      when "treble"
        %(<g data-clef="treble" transform="translate(43 #{TOP + 3 * SPACE}) scale(#{scale} #{-scale})" fill="currentColor"><path d="#{MelodicDictationSvgRenderer::TREBLE_CLEF_PATH}"/></g>)
      when "bass"
        %(<g data-clef="bass" transform="translate(43 #{TOP + SPACE}) scale(#{scale} #{-scale})" fill="currentColor"><path d="#{VoicedDictationSvgRenderer::BASS_CLEF_PATH}"/></g>)
      when "alto"
        # C-clef centre points to middle C, the central staff line.
        %(<g data-clef="alto" fill="currentColor" transform="translate(43 #{TOP})"><rect width="4" height="56"/><rect x="7" width="2" height="56"/><path d="M12 0C38 0 39 19 20 28C39 37 38 56 12 56L12 50C30 50 30 36 14 32L9 28L14 24C30 20 30 6 12 6Z"/></g>)
      else
        raise InvalidContent, "Unsupported clef"
      end
    end

    def ledgers
      index = @exercise.fetch(:staff_position_index)
      positions = index < 0 ? (-2).step(index,-2).to_a : (index > 8 ? 10.step(index,2).to_a : [])
      positions.map { |p| %(<line x1="#{NOTE_X - 16}" y1="#{y(p)}" x2="#{NOTE_X + 16}" y2="#{y(p)}"/>) }.join
    end

    def note
      index = @exercise.fetch(:staff_position_index)
      yy = y(index)
      down = index >= 4
      stem_x = NOTE_X + (down ? -8.4 : 8.4)
      %(<g fill="currentColor"><ellipse cx="#{NOTE_X}" cy="#{yy}" rx="9" ry="6" transform="rotate(-18 #{NOTE_X} #{yy})"/><path d="M#{stem_x} #{yy}v#{down ? 42 : -42}" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/></g>)
    end

    def symbols
      if @exercise[:notation_kind] == "key_signature"
        @exercise.fetch(:key_signature_accidentals).each_with_index.map { |item,i| accidental(item.fetch(:accidental_id),112 + i * 19,y(item.fetch(:staff_position_index))) }.join
      elsif @exercise[:note_accidental_id]
        accidental(@exercise.fetch(:note_accidental_id),NOTE_X - 26,y(@exercise.fetch(:staff_position_index)))
      else
        ""
      end
    end

    def accidental(id,x,yy)
      path = case id
      when "sharp" then '<path d="M-4-13v26M4-15v26M-8-4L8-7M-8 5L8 2" fill="none" stroke="currentColor" stroke-width="2.3"/>'
      when "flat" then '<path d="M-3-16V10C14 2 9-8-3-2" fill="none" stroke="currentColor" stroke-width="2.3"/>'
      when "natural" then '<path d="M-4-15V6L5 3V-7L-4-4M5-7V15" fill="none" stroke="currentColor" stroke-width="2.3"/>'
      when "double_sharp" then '<path d="M-7-7L7 7M-7 7L7-7" fill="none" stroke="currentColor" stroke-width="4"/>'
      when "double_flat" then '<path d="M-7-16V10C5 3 3-7-7-2M2-16V10C14 3 12-7 2-2" fill="none" stroke="currentColor" stroke-width="2.1"/>'
      else raise InvalidContent, "Unsupported accidental"
      end
      %(<g transform="translate(#{x} #{yy})" data-accidental="#{id}">#{path}</g>)
    end
  end
end
