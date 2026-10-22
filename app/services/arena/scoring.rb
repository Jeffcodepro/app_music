module Arena
  module Scoring
    LEGACY = "accuracy-1000-v1".freeze
    CURRENT = "speed-streak-v1".freeze
    VERSIONS = [LEGACY, CURRENT].freeze

    def self.points(duration_ms:, elapsed_ms:, streak:)
      unless duration_ms.is_a?(Integer) && duration_ms.positive? && elapsed_ms.is_a?(Integer) && elapsed_ms >= 0 && elapsed_ms < duration_ms && streak.is_a?(Integer) && streak.positive?
        raise InvalidContent, "Missing or invalid accepted response timing"
      end
      600 + 400 * (duration_ms - elapsed_ms) / duration_ms + 100 * [streak - 1, 4].min
    end
  end
end
