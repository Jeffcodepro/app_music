module Arena
  class Forbidden < StandardError; end
  class Conflict < StandardError; end
  class InvalidTransition < StandardError; end
  class InvalidAnswer < StandardError; end
  class AlreadyAnswered < StandardError; end
  class PrivatePayload < StandardError; end
  class InvalidContent < StandardError; end
  class Unavailable < StandardError; end
  class RateLimited < StandardError; end
end
