class MelodicDictationSvgRenderer
  STAFF_TOP = 58
  STAFF_SPACING = 16
  # Bravura gClef outline, OFL-1.1, with its origin on G4 (second staff line).
  # The source uses 360 units per staff space; see docs/licenses/treble-clef.md.
  TREBLE_CLEF_PATH = "M 541 598 C 539 615 541 616 550 625 C 706 770 824 953 824 1174 C 824 1299 789 1423 730 1509 C 708 1541 671 1581 655 1581 C 635 1581 590 1544 562 1512 C 455 1394 420 1214 420 1064 C 420 981 431 887 441 828 C 444 811 445 808 428 793 C 220 622 0 416 0 125 C 0 -125 171 -363 524 -363 C 557 -363 595 -360 624 -354 C 639 -351 642 -350 645 -367 C 662 -464 684 -589 684 -657 C 684 -870 540 -896 455 -896 C 377 -896 340 -873 340 -854 C 340 -844 353 -840 386 -829 C 431 -816 482 -778 482 -694 C 482 -615 432 -547 344 -547 C 248 -547 190 -624 190 -713 C 190 -806 246 -948 464 -948 C 560 -948 747 -904 747 -660 C 747 -577 721 -441 706 -351 C 703 -334 704 -336 724 -327 C 870 -269 966 -147 966 16 C 966 200 831 363 619 363 C 582 363 582 363 577 389 Z M 677 1358 C 724 1358 763 1319 763 1240 C 763 1080 626 950 513 851 C 503 842 497 844 494 863 C 488 900 485 949 485 995 C 485 1220 589 1358 677 1358 Z M 520 377 C 524 350 524 351 498 343 C 372 300 289 186 289 63 C 289 -66 357 -158 455 -192 C 467 -196 484 -200 494 -200 C 505 -200 511 -193 511 -184 C 511 -174 500 -170 490 -166 C 429 -140 386 -78 386 -12 C 386 71 442 132 530 157 C 553 163 556 161 559 145 L 631 -284 C 634 -300 632 -300 611 -304 C 588 -308 559 -311 530 -311 C 278 -311 115 -171 115 29 C 115 114 130 228 249 363 C 336 459 402 513 469 567 C 484 579 487 577 490 562 Z M 619 148 C 616 166 618 170 635 168 C 752 158 848 60 848 -66 C 848 -157 793 -230 713 -271 C 696 -279 693 -279 690 -262 Z".freeze

  def initialize(pitches)
    unless pitches.is_a?(Array) && pitches.size == 4 && pitches.all? { |p| p.is_a?(String) && p.match?(/\A(?:[CDEFGAB]4|C5)\z/) }
      raise ArgumentError, "expected four natural notes from C4 to C5"
    end
    @notes = pitches.map { |p| MusicTheory::Note.parse(p) }
  end

  def call
    lines = 5.times.map { |i| %(<line x1="24" y1="#{STAFF_TOP + i * STAFF_SPACING}" x2="500" y2="#{STAFF_TOP + i * STAFF_SPACING}"/>) }.join
    notes = @notes.each_with_index.map do |note, i|
      x = 180 + i * 84
      y = 122 - (note.diatonic_index - 30) * 8
      ledger = y >= 138 ? %(<line class="melody-ledger" x1="#{x - 16}" y1="138" x2="#{x + 16}" y2="138"/>) : ""
      up = y > 90
      stem_x = x + (up ? 9 : -9)
      %(#{ledger}<ellipse class="melody-note" cx="#{x}" cy="#{y}" rx="10" ry="7" transform="rotate(-18 #{x} #{y})" fill="currentColor" stroke="none"/><line x1="#{stem_x}" y1="#{y}" x2="#{stem_x}" y2="#{y + (up ? -48 : 48)}"/>)
    end.join
    clef_scale = STAFF_SPACING / 360.0
    clef_y = STAFF_TOP + 3 * STAFF_SPACING
    clef = %(<g class="melody-clef" transform="translate(44 #{clef_y}) scale(#{clef_scale} #{-clef_scale})" fill="currentColor"><path d="#{TREBLE_CLEF_PATH}"/></g>)
    %(<svg viewBox="0 0 520 194" role="img" aria-label="Partitura melódica em clave de Sol" xmlns="http://www.w3.org/2000/svg"><g stroke="currentColor" stroke-width="2">#{lines}<line x1="500" y1="58" x2="500" y2="122"/>#{notes}</g>#{clef}<g fill="currentColor" font-family="serif" font-weight="bold" font-size="32" text-anchor="middle"><text x="123" y="84">4</text><text x="123" y="116">4</text></g></svg>).html_safe
  end
end
