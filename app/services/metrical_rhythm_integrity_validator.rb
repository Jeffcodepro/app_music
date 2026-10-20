class MetricalRhythmIntegrityValidator
  NAMES = { 1 => "semicolcheia", 2 => "colcheia", 3 => "colcheia pontuada", 4 => "semínima", 6 => "semínima pontuada", 8 => "mínima", 12 => "mínima pontuada", 16 => "semibreve" }.freeze

  def self.validate!(exercise) = new(exercise).validate!
  def initialize(exercise) = @e = exercise.to_h.deep_symbolize_keys

  def validate!
    check(@e[:rhythm_format] == "meter-v1")
    level = @e.fetch(:level)
    check(level.is_a?(Integer) && (1..4).cover?(level))
    policy = MusicTheory::Meter.fetch(@e.fetch(:meter_id), level:)
    spec = MusicTheory::Meter::PRESETS.find { |p| p[:id] == @e[:meter_id] }
    meter = @e.fetch(:meter)
    check(meter.is_a?(Hash) && meter[:numerator].is_a?(Integer) && meter[:denominator].is_a?(Integer) &&
      meter[:bpm_unit_steps].is_a?(Integer) && meter[:groups].is_a?(Array) && meter[:groups].all? { |group| group.is_a?(Integer) })
    check(meter.values_at(:numerator, :denominator, :groups, :kind) == spec.values_at(:numerator, :denominator, :groups, :kind))
    # Recalculate from raw notation independently of Meter's derived methods.
    unit = 16 / meter.fetch(:denominator)
    measure = meter.fetch(:numerator) * unit
    groups = meter.fetch(:groups).map { |n| n * unit }
    bpm_unit = meter[:kind] == "compound" ? unit * 3 : unit
    check(meter[:bpm_unit_steps] == bpm_unit)
    mode = @e.fetch(:activity_mode)
    check(%w[pulse subdivision precision].include?(mode))
    profile = @e.key?(:complexity_version) || @e.key?(:requested_meter_id)
    if profile
      check(@e[:complexity_version] == "level-structure-v1")
      check(@e[:requested_meter_id] == "mixed" || @e[:requested_meter_id] == @e[:meter_id])
    end
    check(@e[:requested_activity_mode] == "mixed" || @e[:requested_activity_mode] == mode)
    bars = mode == "pulse" && groups.size == 2 ? 2 : 1
    check(@e[:measure_count].is_a?(Integer) && @e[:total_steps].is_a?(Integer) && @e[:measure_count] == bars && @e[:total_steps] == measure * bars)
    check(@e[:time_signature_label] == "#{meter[:numerator]}/#{meter[:denominator]}")
    label = if meter[:kind] == "compound"
              { 4 => "mínima pontuada", 8 => "semínima pontuada", 16 => "colcheia pontuada" }.fetch(meter[:denominator])
            else
              { 2 => "mínima", 4 => "semínima", 8 => "colcheia", 16 => "semicolcheia" }.fetch(meter[:denominator])
            end
    check(@e[:bpm_unit_label] == label)
    check(@e[:tempo_bpm].is_a?(Integer) && policy.tempo_range.cover?(@e[:tempo_bpm]))
    check(@e[:count_in_beats].is_a?(Integer))
    check(@e[:count_in_beats] == (meter[:kind] == "additive" ? meter[:numerator] : groups.size))
    check(@e[:playback_cycles].is_a?(Integer) && @e[:playback_cycles] == 1 && @e[:metronome_during_pattern] == (mode != "subdivision"))
    check(@e[:question] == "Qual partitura você ouviu?")
    check(@e[:activity_mode_label] == { "pulse" => "Pulso", "subdivision" => "Subdivisão", "precision" => "Precisão" }.fetch(mode))
    options = @e.fetch(:options)
    check(options.is_a?(Array) && options.size == 4)
    ids = options.map { |o| o.fetch(:id) }
    check(ids.uniq.size == 4)
    events = options.map do |option|
      check(option[:pattern_signature] == option[:id])
      tokens = parse(option.fetch(:id))
      check(tokens.size <= 24)
      check(tokens == option[:tokens])
      check(option[:tokens].all? { |token| token[:duration_steps].is_a?(Integer) })
      check(option[:aria_label] == tokens.map { |t| "#{'pausa de ' if t[:kind] == 'rest'}#{NAMES.fetch(t[:duration_steps])}" }.join(', '))
      cursor = 0; index = 0; sounding = []; partitions = []
      (groups * bars).each do |group|
        remaining = group; part = []
        while remaining.positive?
          token = tokens.fetch(index); duration = token[:duration_steps]
          check(duration <= remaining)
          sounding << { start_step: cursor, duration_steps: duration } if token[:kind] == "note"
          cursor += duration; remaining -= duration; index += 1; part << token
        end
        partitions << part
      end
      check(index == tokens.size && cursor == measure * bars && sounding.size >= 2)
      check(partitions.all? { |p| p.size == 1 }) if mode == "pulse"
      check(partitions.any? { |p| p.size >= 2 }) if mode == "subdivision"
      check(partitions.count { |p| p.size >= 2 } >= [2, partitions.size].min) if mode == "precision"
      validate_complexity(tokens, partitions, groups, level, mode) if profile
      sounding
    end
    check(events.map { |es| es.map { |e| e[:start_step] } }.uniq.size == 4)
    check(@e[:audio_events].is_a?(Array) && @e[:audio_events].all? { |event| event[:start_step].is_a?(Integer) && event[:duration_steps].is_a?(Integer) })
    correct_index = events.index(@e[:audio_events])
    check(!correct_index.nil? && ids[correct_index] == @e[:correct_option_id])
    check(options[correct_index][:aria_label] == @e[:correct_option_label])
    check(@e[:signature] == ExerciseIntegrityValidator.digest("metrical-rhythm-v1", @e.except(:signature, :assignment_id, :attempt_token)))
    true
  rescue KeyError, TypeError, NoMethodError, IndexError, ArgumentError => error
    raise error if error.is_a?(ExerciseIntegrityValidator::Invalid)
    raise ExerciseIntegrityValidator::Invalid, "metrical_rhythm_payload"
  end

  private

  # Independent reconstruction of the permitted written structures. No generator
  # predicates or random choices participate in checking an issued assignment.
  def validate_complexity(tokens, partitions, group_lengths, level, mode)
    return if mode == "pulse"
    permitted = group_lengths.map do |length|
      variants = [[length]]
      variants << [length / 2, length / 2] if (length % 2).zero?
      if level >= 2
        variants << Array.new(3, length / 3) if (length % 3).zero?
        variants += [[length / 2, length / 4, length / 4], [length / 4, length / 4, length / 2]] if (length % 4).zero?
      end
      [4, 6].each { |n| variants << Array.new(n, length / n) if level >= 3 && (length % n).zero? }
      variants += [[length - 1, 1], [1, length - 1]] if level == 4 && length > 2
      variants.select { |v| v.all? { |duration| NAMES.key?(duration) } }.uniq
    end
    partitions.each_with_index { |part, index| check(permitted[index % permitted.size].include?(part.map { |t| t[:duration_steps] })) }
    check(tokens.none? { |t| t[:kind] == "rest" && t[:duration_steps] == 1 }) if level == 2
    target = [[2,3,4,4].fetch(level - 1), permitted.flatten(1).map(&:size).max].min
    check(partitions.any? { |part| part.size >= target })
    if level == 4
      check(partitions.map { |part| part.map { |t| t[:token] } }.uniq.size >= 2)
      check(tokens[1...-1].any? { |t| t[:kind] == "rest" })
    end
  end

  def parse(signature)
    check(signature.is_a?(String) && !signature.empty?)
    signature.split('.', -1).map do |token|
      m = /\A([nr])(1|2|3|4|6|8|12|16)\z/.match(token)
      check(m)
      { token:, kind: m[1] == "n" ? "note" : "rest", duration_steps: Integer(m[2], 10) }
    end
  end

  def check(condition)
    raise ExerciseIntegrityValidator::Invalid, "metrical_rhythm_contract" unless condition
  end
end
