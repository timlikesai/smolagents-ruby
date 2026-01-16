require_relative "telemetry/instrumentation"

module Smolagents
  # Telemetry and observability for agent systems.
  #
  # This module provides instrumentation primitives and integrations with
  # observability systems like OpenTelemetry. Use it to track agent execution,
  # measure performance, and debug issues.
  #
  # @example Enable OpenTelemetry tracing
  #   Smolagents::Telemetry.const_defined?(:OTel)  #=> true
  #
  # @example Custom event subscriber
  #   Smolagents::Telemetry::Instrumentation.respond_to?(:subscriber=)  #=> true
  #
  # @see Smolagents::Telemetry::Instrumentation Basic instrumentation
  # @see Smolagents::Telemetry::OTel OpenTelemetry integration
  # @see Smolagents::Telemetry::LoggingSubscriber Simple logging output
  module Telemetry
    autoload :AgentLogger, "smolagents/telemetry/agent_logger"
    autoload :OTel, "smolagents/telemetry/otel"
    autoload :LoggingSubscriber, "smolagents/telemetry/logging_subscriber"
  end
end
