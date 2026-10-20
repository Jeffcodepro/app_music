require "digest"

# New explicit meter contract. The legacy generator/payload remains unchanged.
class MetricalRhythmExerciseGenerator
  DURATIONS = { 1 => "semicolcheia", 2 => "colcheia", 3 => "colcheia pontuada", 4 => "semínima", 6 => "semínima pontuada", 8 => "mínima", 12 => "mínima pontuada", 16 => "semibreve" }.freeze
  QUESTION = "Qual partitura você ouviu?".freeze

  def self.tokens(signature)
    raise RhythmExerciseGenerator::InvalidPattern, "empty_pattern" unless signature.is_a?(String) && !signature.empty?
    signature.split('.', -1).map do |token|
      match = /\A([nr])(1|2|3|4|6|8|12|16)\z/.match(token)
      raise RhythmExerciseGenerator::InvalidPattern, "unknown_token" unless match
      { token:, kind: match[1] == "n" ? "note" : "rest", duration_steps: match[2].to_i }
    end
  end

  def self.option(signature)
    parsed = tokens(signature)
    { id: signature, pattern_signature: signature, tokens: parsed,
      aria_label: parsed.map { |t| "#{'pausa de ' if t[:kind] == 'rest'}#{DURATIONS.fetch(t[:duration_steps])}" }.join(', ') }
  end

  def self.events(signature)
    cursor = 0
    tokens(signature).filter_map do |token|
      event = { start_step: cursor, duration_steps: token[:duration_steps] } if token[:kind] == "note"
      cursor += token[:duration_steps]
      event
    end
  end

  def self.signature(exercise)
    ExerciseIntegrityValidator.digest("metrical-rhythm-v1", exercise.except(:signature, :assignment_id, :attempt_token))
  end

  def initialize(level:, meter_id:, activity_mode: "mixed", random: Random.new, recent_exercises: [])
    @level, @mode, @random, @requested_meter_id = level, activity_mode, random, meter_id
    if meter_id == "mixed"
      # Choose a formula first so extra grouping variants do not bias its odds.
      formulas = MusicTheory::Meter.presets(level:).group_by { |p| p.values_at(:numerator, :denominator) }
      previous = recent_exercises.last.to_h.symbolize_keys[:meter_id]
      choices = formulas.values
      fresh = choices.reject { |variants| variants.any? { |p| p[:id] == previous } }
      chosen = (fresh.presence || choices).sample(random: @random).sample(random: @random)
      meter_id = chosen[:id]
    end
    @meter = MusicTheory::Meter.fetch(meter_id, level:)
    @recent = recent_exercises
    raise RhythmExerciseGenerator::GenerationError, "Unavailable rhythm mode" unless %w[pulse subdivision precision mixed].include?(@mode)
  end

  def call
    mode = @mode == "mixed" ? %w[pulse subdivision precision].sample(random: @random) : @mode
    # Two pulse positions cannot yield four choices with >=2 attacks. Apply the
    # approved two-bar solution to all duple pulse meters; record this in decisions.
    bars = mode == "pulse" && @meter.groups.size == 2 ? 2 : 1
    segments = @meter.group_steps * bars
    alternatives = []
    candidates(segments, mode).each do |pattern|
      parsed = self.class.tokens(pattern)
      next if parsed.size > 24
      attacks = self.class.events(pattern).map { |event| event[:start_step] }
      next if attacks.size < 2 || alternatives.any? { |other| self.class.events(other).map { |e| e[:start_step] } == attacks }
      grouped = segment_tokens(parsed, segments)
      next if mode == "subdivision" && grouped.none? { |g| g.size >= 2 }
      next if mode == "precision" && grouped.count { |g| g.size >= 2 } < [2, segments.size].min
      next unless complexity_matches?(parsed, grouped, segments, mode)
      alternatives << pattern
      break if alternatives.size == 4
    end
    raise RhythmExerciseGenerator::GenerationError, "No four distinct rhythms within generation budget" unless alternatives.size == 4
    recent_patterns = @recent.filter_map do |entry|
      e = entry.to_h.symbolize_keys
      e[:signature] || e[:pattern_signature] if e[:meter_id] == @meter.id && e[:activity_mode] == mode
    end
    correct = (alternatives - recent_patterns).sample(random: @random) || alternatives.sample(random: @random)
    options = alternatives.shuffle(random: @random).map { |s| self.class.option(s) }
    exercise = {
      rhythm_format: "meter-v1", complexity_version: "level-structure-v1", requested_meter_id: @requested_meter_id,
      level: @level, meter_id: @meter.id, meter: @meter.to_h,
      measure_count: bars, total_steps: @meter.measure_steps * bars, bpm_unit_label: @meter.bpm_unit_label,
      requested_activity_mode: @mode, activity_mode: mode, activity_mode_label: RhythmExerciseGenerator.activity_mode_definition(mode)[:label],
      question: QUESTION, tempo_bpm: @random.rand(@meter.tempo_range), time_signature_label: @meter.label,
      count_in_beats: @meter.click_steps.size, metronome_during_pattern: mode != "subdivision", playback_cycles: 1,
      audio_events: self.class.events(correct), correct_option_id: correct,
      correct_option_label: options.find { |o| o[:id] == correct }[:aria_label], options:
    }
    exercise[:signature] = self.class.signature(exercise)
    exercise
  end

  private

  def candidates(segments, mode)
    # Exhaust small finite spaces rather than relying on repeatedly drawing rare
    # alternatives (notably advanced precision in 2/8).
    variants = segments.map do |size|
      divisions = mode == "pulse" ? [[size]] : partitions(size)
      divisions.flat_map do |division|
        choices = division.map { |duration| mode != "pulse" && @level == 2 && duration == 1 ? ["n#{duration}"] : ["n#{duration}", "r#{duration}"] }
        choices.reduce([[]]) { |prefixes, options| prefixes.flat_map { |p| options.map { |o| p + [o] } } }
      end
    end
    if variants.map(&:size).reduce(:*) <= 4096
      variants.reduce([[]]) { |prefixes, options| prefixes.flat_map { |p| options.map { |o| p + o } } }.map { |tokens| tokens.join('.') }.shuffle(random: @random)
    else
      Array.new(400) { segments.flat_map { |size| motif(size, mode) }.join('.') }
    end
  end

  def motif(size, mode)
    return ["#{@random.rand(4).zero? ? 'r' : 'n'}#{size}"] if mode == "pulse"
    partitions(size).sample(random: @random).map do |duration|
      rest = @random.rand(@level >= 3 ? 4 : 6).zero? && !(@level == 2 && duration == 1)
      "#{rest ? 'r' : 'n'}#{duration}"
    end
  end

  def partitions(size)
    choices = [[size]]
    choices << [size / 2] * 2 if size.even?
    if @level >= 2
      choices << [size / 3] * 3 if (size % 3).zero?
      if (size % 4).zero?
        choices += [[size / 2, size / 4, size / 4], [size / 4, size / 4, size / 2]]
      end
    end
    if @level >= 3
      [4,6].each { |count| choices << [size / count] * count if (size % count).zero? }
    end
    choices += [[size - 1, 1], [1, size - 1]] if @level == 4 && size > 2
    choices.select { |p| p.all? { |d| DURATIONS.key?(d) } }.uniq
  end

  def complexity_matches?(tokens, groups, segments, mode)
    return true if mode == "pulse"
    target = [@level == 1 ? 2 : (@level == 2 ? 3 : 4), segments.map { |s| partitions(s).map(&:size).max }.max].min
    return false unless groups.any? { |g| g.size >= target }
    return true unless @level == 4
    groups.map { |g| g.map { |t| t[:token] } }.uniq.size >= 2 && tokens[1...-1].any? { |t| t[:kind] == "rest" }
  end

  def segment_tokens(tokens, segments)
    index = 0
    segments.map do |length|
      group = []; duration = 0
      while duration < length
        token = tokens.fetch(index); group << token; duration += token[:duration_steps]; index += 1
      end
      group
    end
  end
end
