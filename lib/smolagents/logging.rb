require_relative "logging/null_logger"
require_relative "logging/raw_output_logger"

module Smolagents
  # Logging utilities for smolagents.
  #
  # Provides structured logging for debugging agent behavior and preserving
  # raw model outputs for analysis.
  #
  # @example Using RawOutputLogger
  #   require "smolagents/logging"
  #
  #   Smolagents::Logging::RawOutputLogger.open(directory: "logs") do |logger|
  #     logger.log_run(model_id: "gpt-4", config: "test", data: result)
  #   end
  #
  module Logging
  end
end
