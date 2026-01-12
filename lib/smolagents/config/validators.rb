module Smolagents
  module Config
    VALIDATORS = {
      log_format: ->(val) { %i[text json].include?(val) or raise ArgumentError, "log_format must be :text or :json" },
      log_level: ->(val) { %i[debug info warn error].include?(val) or raise ArgumentError, "log_level must be :debug, :info, :warn, or :error" },
      max_steps: ->(val) { val.nil? || val.positive? or raise ArgumentError, "max_steps must be positive" },
      custom_instructions: ->(val) { val.nil? || val.length <= 10_000 or raise ArgumentError, "custom_instructions too long (max 10,000 chars)" }
    }.freeze
  end
end
