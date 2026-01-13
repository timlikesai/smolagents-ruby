module Smolagents
  module Telemetry
    # OpenTelemetry integration for distributed tracing.
    #
    # OTel provides automatic trace generation for agent operations, enabling
    # visibility into agent execution across distributed systems. Traces include
    # tool calls, step execution, and error information.
    #
    # @example Enable tracing
    #   Smolagents::Telemetry::OTel.enable(service_name: "research-agent")
    #
    # @example Disable tracing
    #   Smolagents::Telemetry::OTel.disable
    #
    # @example Check if enabled
    #   if Smolagents::Telemetry::OTel.enabled?
    #     puts "Tracing is active"
    #   end
    #
    # @note Requires the opentelemetry-sdk and opentelemetry-exporter-otlp gems
    module OTel
      class << self
        attr_reader :tracer

        def enable(service_name: "smolagents")
          require "opentelemetry-sdk"
          require "opentelemetry-exporter-otlp"

          OpenTelemetry::SDK.configure do |config|
            config.service_name = service_name
            config.use_all
          end

          @tracer = OpenTelemetry.tracer_provider.tracer(service_name)
          Instrumentation.subscriber = method(:handle_event)
          true
        rescue LoadError => e
          raise LoadError,
                "OpenTelemetry gems required. Add to your Gemfile:\n  " \
                "gem 'opentelemetry-sdk'\n  " \
                "gem 'opentelemetry-exporter-otlp'\n" \
                "Original error: #{e.message}"
        end

        def disable
          Instrumentation.subscriber = nil
          @tracer = nil
        end

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
          @tracer.in_span(name, attributes: attributes) do |span|
            span.set_attribute("smolagents.status", "ok")
          end
        end

        def record_error_span(name, attributes, payload)
          @tracer.in_span(name, attributes: attributes) do |span|
            span.set_attribute("smolagents.status", "error")
            span.set_attribute("smolagents.error_class", payload[:error].to_s)
            span.status = OpenTelemetry::Trace::Status.error(payload[:error].to_s)
          end
        end
      end
    end
  end
end
