# frozen_string_literal: true

module Smolagents
  module Config
    VALIDATORS = {
      log_format: ->(v) { %i[text json].include?(v) or raise ArgumentError, "log_format must be :text or :json" },
      log_level: ->(v) { %i[debug info warn error].include?(v) or raise ArgumentError, "log_level must be :debug, :info, :warn, or :error" },
      max_steps: ->(v) { v.nil? || v.positive? or raise ArgumentError, "max_steps must be positive" },
      custom_instructions: ->(v) { v.nil? || v.length <= 10_000 or raise ArgumentError, "custom_instructions too long (max 10,000 chars)" }
    }.freeze
  end
end
