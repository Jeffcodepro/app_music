class RhythmExerciseGenerator
  ACTIVITY_MODES = [
    { id: "pulse", label: "Pulso" },
    { id: "subdivision", label: "Subdivisão" },
    { id: "syncopation", label: "Síncopa" },
    { id: "precision", label: "Precisão" },
    { id: "mixed", label: "Misto" }
  ].freeze

  MODE_CONFIGS = {
    "pulse" => {
      focus_label: "Pulso estável",
      description: "Ouça um compasso em 4/4 e escolha a partitura que representa corretamente os ataques no pulso principal.",
      prompt_value: "Ataques alinhados ao pulso principal",
      metronome_during_pattern: true,
      playback_cycles: 1,
      tempo_range: 70..92,
      motifs: [
        %w[n4],
        %w[n4],
        %w[n4],
        %w[r4]
      ]
    },
    "subdivision" => {
      focus_label: "Subdivisão interna",
      description: "Ouça as subdivisões do compasso e identifique a escrita rítmica correspondente.",
      prompt_value: "Escute as subdivisões dentro de cada tempo",
      metronome_during_pattern: false,
      playback_cycles: 2,
      tempo_range: 74..98,
      motifs: [
        %w[n4],
        %w[n2 n2],
        %w[n1 n1 n2],
        %w[n2 n1 n1],
        %w[n1 n1 n1 n1],
        %w[n2 r2]
      ]
    },
    "syncopation" => {
      focus_label: "Síncopa",
      description: "Ouça o deslocamento rítmico e escolha a alternativa que melhor representa os ataques fora do tempo forte.",
      prompt_value: "Atenção aos ataques fora do tempo forte",
      metronome_during_pattern: false,
      playback_cycles: 2,
      tempo_range: 78..108,
      motifs: [
        %w[r2 n2],
        %w[r1 n1 n2],
        %w[r2 n1 n1],
        %w[n1 r1 n2],
        %w[n2 r1 n1]
      ]
    },
    "precision" => {
      focus_label: "Precisão temporal",
      description: "Ouça o padrão com referência métrica e reconheça a partitura com a distribuição exata dos ataques.",
      prompt_value: "Metrônomo ativo durante a execução",
      metronome_during_pattern: true,
      playback_cycles: 2,
      tempo_range: 82..116,
      motifs: [
        %w[n2 n2],
        %w[n1 n1 n2],
        %w[n2 n1 n1],
        %w[n1 n1 n1 n1],
        %w[n2 r1 n1],
        %w[r1 n1 n2],
        %w[n1 r1 n1 n1],
        %w[r2 n1 n1]
      ]
    }
  }.freeze

  TOKEN_LABELS = {
    "n4" => "semínima",
    "n2" => "colcheia",
    "n1" => "semicolcheia",
    "r4" => "pausa de semínima",
    "r2" => "pausa de colcheia",
    "r1" => "pausa de semicolcheia"
  }.freeze

  DEFAULT_ACTIVITY_MODE = "mixed".freeze
  BEATS_PER_MEASURE = 4
  STEPS_PER_BEAT = 4
  TOTAL_STEPS = BEATS_PER_MEASURE * STEPS_PER_BEAT

  def self.activity_modes
    ACTIVITY_MODES
  end

  def self.activity_mode_ids
    ACTIVITY_MODES.map { |mode| mode[:id] }
  end

  def self.activity_mode_definition(id)
    ACTIVITY_MODES.find { |mode| mode[:id] == id.to_s }
  end

  def self.mode_config(id)
    MODE_CONFIGS.fetch(id.to_s)
  end

  def self.parse_pattern_signature(signature)
    signature.to_s.split(".").filter_map do |token|
      match = token.match(/\A([nr])(1|2|4)\z/)
      next if match.blank?

      {
        token:,
        kind: match[1] == "n" ? "note" : "rest",
        duration_steps: match[2].to_i
      }
    end
  end

  def self.pattern_signature(tokens)
    Array(tokens).join(".")
  end

  def self.option_from_signature(signature)
    tokens = parse_pattern_signature(signature)
    return if tokens.blank?
    return if tokens.sum { |token| token[:duration_steps] } != TOTAL_STEPS

    {
      id: signature.to_s,
      pattern_signature: signature.to_s,
      tokens:,
      aria_label: pattern_aria_label(tokens)
    }
  end

  def self.audio_events_for_signature(signature)
    cursor = 0
    parse_pattern_signature(signature).filter_map do |token|
      event = if token[:kind] == "note"
                {
                  start_step: cursor,
                  duration_steps: token[:duration_steps]
                }
              end
      cursor += token[:duration_steps]
      event
    end
  end

  def self.exercise_signature(activity_mode:, pattern_signature:, tempo_bpm:)
    [activity_mode, pattern_signature, tempo_bpm].join("|")
  end

  def self.description_for(activity_mode)
    mode_config(activity_mode)[:description]
  end

  def self.prompt_value_for(activity_mode)
    mode_config(activity_mode)[:prompt_value]
  end

  def self.focus_label_for(activity_mode)
    mode_config(activity_mode)[:focus_label]
  end

  def self.metronome_during_pattern?(activity_mode)
    mode_config(activity_mode)[:metronome_during_pattern]
  end

  def self.playback_cycles_for(activity_mode)
    mode_config(activity_mode)[:playback_cycles]
  end

  def self.pattern_aria_label(tokens)
    Array(tokens).map { |token| TOKEN_LABELS[token[:token]] || token[:token] }.join(", ")
  end

  def initialize(random: Random.new, activity_mode: DEFAULT_ACTIVITY_MODE, recent_exercises: [])
    @random = random
    @activity_mode = sanitize_activity_mode(activity_mode)
    @recent_exercises = Array(recent_exercises).map { |entry| entry.to_h.symbolize_keys }
  end

  def call
    resolved_mode = sampled_activity_mode
    tempo_bpm = sampled_tempo_bpm(resolved_mode)
    correct_segments = sampled_segments(resolved_mode)
    correct_pattern_signature = self.class.pattern_signature(correct_segments.flatten)
    option_signatures = build_option_signatures(resolved_mode, correct_segments, correct_pattern_signature)
    correct_option = self.class.option_from_signature(correct_pattern_signature)
    activity_mode_definition = self.class.activity_mode_definition(resolved_mode)
    options = option_signatures.map { |signature| self.class.option_from_signature(signature) }

    {
      activity_mode: resolved_mode,
      activity_mode_label: activity_mode_definition[:label],
      question: self.class.description_for(resolved_mode),
      prompt_label: "Escuta",
      prompt_value: self.class.prompt_value_for(resolved_mode),
      focus_label: self.class.focus_label_for(resolved_mode),
      tempo_bpm:,
      time_signature_label: "4/4",
      count_in_beats: BEATS_PER_MEASURE,
      metronome_during_pattern: self.class.metronome_during_pattern?(resolved_mode),
      playback_cycles: self.class.playback_cycles_for(resolved_mode),
      audio_events: self.class.audio_events_for_signature(correct_pattern_signature),
      correct_option_id: correct_pattern_signature,
      correct_option_label: correct_option[:aria_label],
      options:,
      signature: self.class.exercise_signature(
        activity_mode: resolved_mode,
        pattern_signature: correct_pattern_signature,
        tempo_bpm:
      )
    }
  end

  private

  def sanitize_activity_mode(activity_mode)
    activity_mode = activity_mode.to_s
    return activity_mode if self.class.activity_mode_ids.include?(activity_mode)

    DEFAULT_ACTIVITY_MODE
  end

  def sampled_activity_mode
    return @activity_mode unless @activity_mode == DEFAULT_ACTIVITY_MODE

    recent_modes = @recent_exercises.last(2).filter_map { |entry| entry[:activity_mode].presence }
    available_modes = self.class.activity_mode_ids - [DEFAULT_ACTIVITY_MODE]
    candidates = available_modes - recent_modes
    sample_from(candidates.presence || available_modes)
  end

  def sampled_tempo_bpm(activity_mode)
    range = self.class.mode_config(activity_mode)[:tempo_range]
    @random.rand(range)
  end

  def sampled_segments(activity_mode)
    attempts = 0

    loop do
      segments = Array.new(BEATS_PER_MEASURE) { sample_from(self.class.mode_config(activity_mode)[:motifs]).dup }
      return segments if valid_segments_for_mode?(segments, activity_mode) && not_recent_signature?(activity_mode, segments)

      attempts += 1
      return segments if attempts >= 36
    end
  end

  def build_option_signatures(activity_mode, correct_segments, correct_signature)
    distractors = []
    attempts = 0

    while distractors.size < 3 && attempts < 90
      variant_segments = deep_dup_segments(correct_segments)
      mutation_count = distractors.empty? ? 1 : 2

      mutation_count.times do
        beat_index = @random.rand(BEATS_PER_MEASURE)
        replacement = replacement_motif_for(activity_mode, variant_segments[beat_index])
        variant_segments[beat_index] = replacement if replacement.present?
      end

      variant_segments.shuffle!(random: @random) if attempts % 5 == 4
      signature = self.class.pattern_signature(variant_segments.flatten)

      if signature != correct_signature &&
         distractors.exclude?(signature) &&
         valid_segments_for_mode?(variant_segments, activity_mode)
        distractors << signature
      end

      attempts += 1
    end

    while distractors.size < 3
      candidate_segments = sampled_segments(activity_mode)
      signature = self.class.pattern_signature(candidate_segments.flatten)
      distractors << signature if signature != correct_signature && distractors.exclude?(signature)
    end

    ([correct_signature] + distractors).shuffle(random: @random)
  end

  def replacement_motif_for(activity_mode, current_motif)
    motifs = self.class.mode_config(activity_mode)[:motifs]
    candidates = motifs.reject { |motif| motif == current_motif }
    sample_from(candidates)&.dup
  end

  def valid_segments_for_mode?(segments, activity_mode)
    flattened = segments.flatten
    note_count = flattened.count { |token| token.start_with?("n") }
    return false if note_count < 2

    case activity_mode
    when "pulse"
      segments.count { |segment| segment == %w[n4] } >= 2
    when "subdivision"
      segments.any? { |segment| segment.size >= 2 }
    when "syncopation"
      segments.count { |segment| segment.first.start_with?("r") } >= 2
    when "precision"
      segments.count { |segment| segment.size >= 3 } >= 2
    else
      true
    end
  end

  def not_recent_signature?(activity_mode, segments)
    signature = self.class.pattern_signature(segments.flatten)
    recent_signatures = @recent_exercises.filter_map do |entry|
      next unless entry[:activity_mode] == activity_mode

      entry[:signature]
    end

    !recent_signatures.include?(signature)
  end

  def deep_dup_segments(segments)
    segments.map(&:dup)
  end

  def sample_from(collection)
    collection[@random.rand(collection.size)]
  end
end
