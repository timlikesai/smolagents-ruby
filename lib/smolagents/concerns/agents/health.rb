module Smolagents
  module Concerns
    module AgentHealth
      # K8s-style health checks for agents.
      #
      # Provides liveness and readiness probes following Kubernetes conventions:
      #
      # - *Liveness* (`live?`): Can the agent accept traffic? Basic operational check.
      # - *Readiness* (`ready?`): Are all dependencies ready? Model loaded, tools initialized.
      #
      # @example Basic health checks
      #   agent.live?   # => true if agent can process requests
      #   agent.ready?  # => true if model healthy and tools initialized
      #
      # @example K8s probe endpoint
      #   get "/health/live" do
      #     json agent.liveness_probe
      #   end
      #
      #   get "/health/ready" do
      #     json agent.readiness_probe
      #   end
      #
      # @see ModelHealth For model-level health checks
      module Health
        def self.included(base)
          base.include(Events::Emitter)
        end

        # Check if agent is alive and can accept requests.
        #
        # Liveness checks verify the agent is operational and not stuck.
        # A failing liveness check indicates the agent should be restarted.
        #
        # @return [Boolean] true if agent is operational
        def live?
          return false unless @model
          return false unless @memory

          true
        end

        # Check if agent is ready to handle requests.
        #
        # Readiness checks verify all dependencies are satisfied.
        # A failing readiness check means traffic should not be routed here.
        #
        # @return [Boolean] true if agent is fully ready
        def ready?
          return false unless live?
          return false unless model_ready?
          return false unless tools_ready?

          true
        end

        # K8s-compatible liveness probe response.
        #
        # @return [Hash] Probe result with status and details
        def liveness_probe
          status = live?
          {
            status: status ? "ok" : "fail",
            checks: {
              model_present: !@model.nil?,
              memory_present: !@memory.nil?
            },
            timestamp: Time.now.iso8601
          }
        end

        # K8s-compatible readiness probe response.
        #
        # @return [Hash] Probe result with status and dependency details
        def readiness_probe
          checks = readiness_checks
          status = checks.values.all?
          {
            status: status ? "ok" : "fail",
            checks:,
            timestamp: Time.now.iso8601
          }
        end

        private

        def model_ready?
          return false unless @model

          # If model supports health checks, use them
          return @model.healthy?(cache_for: 30) if @model.respond_to?(:healthy?)

          # Otherwise assume ready if model exists
          true
        end

        def tools_ready?
          return true if @tools.nil? || @tools.empty?

          # All tools must be initialized
          @tools.values.all? { |tool| tool_initialized?(tool) }
        end

        def tool_initialized?(tool)
          return tool.initialized? if tool.respond_to?(:initialized?)

          true
        end

        def readiness_checks
          {
            live: live?,
            model_healthy: model_ready?,
            tools_initialized: tools_ready?
          }
        end
      end
    end
  end
end
