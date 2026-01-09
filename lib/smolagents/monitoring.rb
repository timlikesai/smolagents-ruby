# frozen_string_literal: true

require_relative "monitoring/callback_registry"
require_relative "monitoring/agent_logger"

module Smolagents
  # Monitoring module provides observability for agents.
  #
  # Features:
  # - Event callbacks for agent lifecycle
  # - Structured logging
  # - Performance tracking (via Monitorable concern)
  #
  # @example Using callbacks
  #   agent.register_callback(:step_complete) do |step, monitor|
  #     puts "Step #{step.step_number} took #{monitor.duration}s"
  #   end
  #
  # @example Using logger
  #   logger = Smolagents::Monitoring::AgentLogger.new
  #   logger.info("Agent started", task: task_description)
  module Monitoring
  end
end
