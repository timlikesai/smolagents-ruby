require_relative "logging/agent_logger"

module Smolagents
  # Logging utilities for agent execution tracking.
  #
  # This module provides structured logging capabilities designed for AI agent
  # workflows, including step-by-step execution tracking and JSON output format
  # for observability systems.
  #
  # @example Basic logging setup
  #   logger = Smolagents::Logging::AgentLogger.new(level: Smolagents::Logging::AgentLogger::DEBUG)
  #   logger.step_start(1, task: "search")
  #   logger.step_complete(1, duration: 0.5)
  #
  # @example JSON format for observability
  #   logger = Smolagents::Logging::AgentLogger.new(format: :json)
  #   logger.info("Tool executed", tool: "search", query: "Ruby")
  #   # => {"timestamp":"2024-01-15T10:30:00Z","level":"INFO","message":"Tool executed","tool":"search","query":"Ruby"}
  #
  # @see Smolagents::Logging::AgentLogger Main logger implementation
  module Logging
  end
end
