require_relative "logging/null_logger"
require_relative "logging/raw_output_logger"

module Smolagents
  # Logging utilities for smolagents.
  #
  # Provides structured logging for debugging agent behavior and preserving
  # raw model outputs for analysis.
  #
  # @example Check available loggers
  #   defined?(Smolagents::Logging::NullLogger)  #=> "constant"
  #
  module Logging
  end
end
