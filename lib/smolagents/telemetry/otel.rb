module Smolagents
  module Telemetry
    # OpenTelemetry integration for distributed tracing and observability.
    #
    # Provides automatic trace generation for agent operations, enabling
    # visibility into agent execution across distributed systems. Traces include:
    # - Tool calls and completions
    # - Agent steps and task completion
    # - Model generation requests
    # - Code executor operations
    # - Error and recovery events
    #
    # Requires the opentelemetry-sdk and opentelemetry-exporter-otlp gems:
    #   gem 'opentelemetry-sdk'
    #   gem 'opentelemetry-exporter-otlp'
    #
    # Once enabled, all agent operations emit OpenTelemetry spans that are
    # automatically exported to configured OTLP endpoints (e.g., Jaeger, Tempo).
    #
    # @example Enable tracing with default configuration
    #   Smolagents::Telemetry::OTel.enable(service_name: "research-agent")
    #   agent = Smolagents.code.model { ... }.build
    #   agent.run("task")  # Spans are automatically exported
    #
    # @example Check if enabled before using
    #   if Smolagents::Telemetry::OTel.enabled?
    #     puts "OpenTelemetry tracing is active"
    #   end
    #
    # @example Disable tracing
    #   Smolagents::Telemetry::OTel.disable
    #
    # @see Instrumentation Low-level instrumentation data collection
    # @see LoggingSubscriber Simple logging alternative
    #
    module OTel
      class << self
        # @return [OpenTelemetry::SDK::Trace::Tracer, nil] The OpenTelemetry tracer or nil if disabled
        attr_reader :tracer

        # Enables OpenTelemetry tracing for all agent operations.
        #
        # Configures OpenTelemetry SDK and registers a subscriber that emits
        # spans for all instrumentation events. Once enabled, all agent operations
        # automatically generate traces.
        #
        # @param service_name [String] Service name for traces (default: "smolagents")
        # @return [Boolean] True if successfully enabled
        # @raise [LoadError] If opentelemetry-sdk or opentelemetry-exporter-otlp gems are not installed
        #
        # @example
        #   Smolagents::Telemetry::OTel.enable(service_name: "my-agent")
        #
        # @see https://opentelemetry.io Ruby OpenTelemetry documentation
        def enable(service_name: "smolagents")
          require "opentelemetry-sdk"
          require "opentelemetry-exporter-otlp"

          configure_opentelemetry(service_name)
          @tracer = OpenTelemetry.tracer_provider.tracer(service_name)
          Instrumentation.subscriber = method(:handle_event)
          true
        rescue LoadError => e
          raise_load_error(e)
        end

        def configure_opentelemetry(service_name)
          OpenTelemetry::SDK.configure do |config|
            config.service_name = service_name
            config.use_all
          end
        end

        def raise_load_error(original)
          raise LoadError, "OpenTelemetry gems required. Add to your Gemfile:\n  " \
                           "gem 'opentelemetry-sdk'\n  gem 'opentelemetry-exporter-otlp'\n" \
                           "Original error: #{original.message}"
        end

        # Disables OpenTelemetry tracing.
        #
        # Unregisters the instrumentation subscriber and clears the tracer.
        # Future operations will not emit traces.
        #
        # @return [nil]
        def disable
          Instrumentation.subscriber = nil
          @tracer = nil
        end

        # Checks if OpenTelemetry tracing is currently enabled.
        #
        # @return [Boolean] True if enabled, false otherwise
        def enabled? = !@tracer.nil?

        private

        def handle_event(event, payload)
          return unless @tracer

          span_name = event.to_s.tr(".", "/")
          attributes = build_attributes(payload)

          if payload[:error]
            record_error_span(span_name, attributes, payload)
          else
            record_span(span_name, attributes, payload)
          end
        end

        def build_attributes(payload)
          attrs = {}

          payload.each do |key, value|
            next if %i[error duration].include?(key)
            next unless serializable?(value)

            attrs["smolagents.#{key}"] = value.to_s
          end

          attrs["smolagents.duration_ms"] = (payload[:duration] * 1000).round(2) if payload[:duration]
          attrs
        end

        def serializable?(value)
          case value
          when String, Symbol, Numeric, TrueClass, FalseClass then true
          else false
          end
        end

        def record_span(name, attributes, _payload)
          @tracer.in_span(name, attributes:) do |span|
            span.set_attribute("smolagents.status", "ok")
          end
        end

        def record_error_span(name, attributes, payload)
          @tracer.in_span(name, attributes:) do |span|
            span.set_attribute("smolagents.status", "error")
            span.set_attribute("smolagents.error_class", payload[:error].to_s)
            span.status = OpenTelemetry::Trace::Status.error(payload[:error].to_s)
          end
        end
      end
    end
  end
end
