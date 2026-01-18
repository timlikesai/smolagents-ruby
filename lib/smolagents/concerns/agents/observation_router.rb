require_relative "observation_router/types"
require_relative "observation_router/model_router"

module Smolagents
  module Concerns
    # Routes tool observations through intelligent summarization.
    #
    # Acts as a gatekeeper deciding how much of a tool's output
    # the agent needs to see. Based on MemR³ router pattern.
    #
    # @see https://arxiv.org/abs/2512.20237 MemR³ retrieve/reflect/answer
    # @see https://arxiv.org/abs/2508.21433 The Complexity Trap research
    module ObservationRouter
      # Hook for setting a custom observation router.
      # @return [Proc, nil] The configured router (nil = use default)
      attr_accessor :observation_router

      # Flag to disable routing entirely.
      # @return [Boolean] false to disable routing
      attr_writer :routing_enabled

      def routing_enabled? = @routing_enabled != false

      private

      # Routes observations through the router (defaults to agent's model).
      # Called from CodeExecution#build_observations.
      #
      # @param raw_observation [String] Combined output from tool execution
      # @param action_step [ActionStep] Current step with tool call info
      # @return [String] Routed observation for the agent
      def route_observations(raw_observation, _action_step)
        return raw_observation if skip_routing?(raw_observation)

        tool_names = extract_tool_names
        return raw_observation if tool_names.empty?

        router = observation_router || default_router
        result = router.call(tool_names.join(", "), raw_observation, current_task)
        result.to_observation
      rescue StandardError => e
        "[Router error: #{e.message}]\n#{raw_observation}"
      end

      def skip_routing?(obs) = obs.nil? || obs.empty? || !routing_enabled?

      # Default router uses the agent's model.
      def default_router
        @default_router ||= ModelRouter.create(@model)
      end

      def extract_tool_names
        return [] unless @executor.respond_to?(:tool_calls)

        @executor.tool_calls
                 .reject { |c| c.tool_name == "final_answer" }
                 .map(&:tool_name)
                 .uniq
      end

      def current_task
        return @current_task if defined?(@current_task) && @current_task
        return @memory.task if @memory.respond_to?(:task)

        "Unknown task"
      end
    end
  end
end
