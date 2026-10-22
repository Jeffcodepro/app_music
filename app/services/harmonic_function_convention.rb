# Editorial vocabulary, not a universal deduction from chord pitches. Keep the
# existing assignments until a music educator approves a replacement version.
module HarmonicFunctionConvention
  VERSION = "major-functions-legacy-v1".freeze
  BY_DEGREE = { 1 => "tonic", 2 => "subdominant", 3 => "tonic", 4 => "subdominant", 5 => "dominant", 6 => "tonic", 7 => "leading_tone" }.freeze
  INSTRUCTION = "Convenção didática: I, III e VI = tônica; II e IV = subdominante; V = dominante; VII = sensível.".freeze

  def self.function(degree, version:)
    raise ArgumentError, "Unknown harmonic function convention" unless version == VERSION
    BY_DEGREE.fetch(degree)
  end
end
