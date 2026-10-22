module MusicTheory
  # Exact sixteenth-note grid for this curriculum; not a student proficiency model.
  class Meter
    TICKS_PER_WHOLE = 16
    GROUPS = { 5 => [[2, 3], [3, 2]], 7 => [[2, 2, 3], [2, 3, 2], [3, 2, 2]],
               8 => [[3, 3, 2]], 10 => [[3, 3, 2, 2]], 11 => [[3, 3, 3, 2]], 13 => [[3, 3, 3, 2, 2]] }.freeze
    PRESETS = begin
      entries = []
      add = lambda do |n, d, level, kind, groups|
        id = [n, d, *(kind == "additive" ? groups : [])].join("-")
        entries << { id: id.freeze, numerator: n, denominator: d, level:, kind: kind.freeze, groups: groups.freeze }.freeze
      end
      [2, 3, 4].each { |n| add.call(n, 4, 1, "simple", [1] * n) }
      add.call(2, 2, 2, "simple", [1, 1]); add.call(3, 8, 2, "simple", [1, 1, 1]); add.call(6, 8, 2, "compound", [3, 3])
      [[3, 2], [4, 2], [2, 8], [4, 8]].each { |n, d| add.call(n, d, 3, "simple", [1] * n) }
      [[9, 8], [12, 8], [6, 4], [9, 4], [12, 4], [6, 16], [9, 16], [12, 16]].each { |n, d| add.call(n, d, 3, "compound", [3] * (n / 3)) }
      [8, 16].each { |d| GROUPS.each { |n, variants| variants.each { |g| add.call(n, d, 4, "additive", g) } } }
      [5, 7].each { |n| GROUPS.fetch(n).each { |g| add.call(n, 4, 4, "additive", g) } }
      entries.freeze
    end

    attr_reader :id, :numerator, :denominator, :groups, :kind, :introduced_at

    def self.presets(level: 4)
      raise ArgumentError, "invalid content level" unless level.is_a?(Integer) && (1..4).cover?(level)
      PRESETS.select { |entry| entry[:level] <= level }
    end

    def self.fetch(id, level: 4)
      entry = presets(level:).find { |preset| preset[:id] == id }
      raise ArgumentError, "unknown meter for this content level" unless entry
      new(entry)
    end

    def initialize(entry)
      @id, @numerator, @denominator, @kind, @introduced_at = entry.values_at(:id, :numerator, :denominator, :kind, :level)
      @groups = entry.fetch(:groups).dup.freeze
      freeze
    end

    def unit_steps = TICKS_PER_WHOLE / denominator
    def measure_steps = numerator * unit_steps
    def group_steps = groups.map { |n| n * unit_steps }
    def group_starts
      cursor = 0
      group_steps.map { |duration| start = cursor; cursor += duration; start }
    end
    def bpm_unit_steps = kind == "compound" ? 3 * unit_steps : unit_steps
    def click_steps = kind == "additive" ? Array.new(numerator) { |i| i * unit_steps } : group_starts
    def accent_steps = kind == "additive" ? group_starts : [0]
    def label = "#{numerator}/#{denominator}"
    def option_label = kind == "additive" ? "#{label} · #{groups.join('+')}" : label
    def bpm_unit_label
      { 1 => "semicolcheia", 2 => "colcheia", 3 => "colcheia pontuada", 4 => "semínima", 6 => "semínima pontuada", 8 => "mínima", 12 => "mínima pontuada" }.fetch(bpm_unit_steps)
    end
    def tempo_range
      return denominator == 4 ? (60..90) : (120..180) if kind == "additive"
      return 60..84 if introduced_at == 1
      return kind == "compound" ? (48..72) : (60..96) if introduced_at == 2
      52..84
    end
    private_class_method :new

    def to_h
      { numerator:, denominator:, groups:, kind:, bpm_unit_steps: }
    end
  end
end
