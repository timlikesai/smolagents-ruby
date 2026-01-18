module Smolagents
  module Security
    # Individual spawn policy violation.
    #
    # Records a specific policy violation with type and contextual details.
    # Used by SpawnValidation to report why a spawn request was denied.
    #
    # @example Creating violations
    #   v = SpawnViolation.depth_exceeded(current: 3, max: 2)
    #   v.to_s  #=> "Depth limit exceeded: at depth 3, max is 2"
    #
    # @see SpawnPolicy For policy validation
    # @see SpawnValidation For validation results
    SpawnViolation = Data.define(:type, :detail) do
      def self.depth_exceeded(current:, max:)
        new(type: :depth_exceeded, detail: { current:, max: }.freeze)
      end

      def self.unauthorized_tool(tool_name)
        new(type: :unauthorized_tool, detail: { tool: tool_name }.freeze)
      end

      def self.steps_exceeded(requested:, max_per_agent:, remaining:)
        new(type: :steps_exceeded, detail: { requested:, max_per_agent:, remaining: }.freeze)
      end

      def to_s
        case type
        when :depth_exceeded
          "Depth limit exceeded: at depth #{detail[:current]}, max is #{detail[:max]}"
        when :unauthorized_tool
          "Tool :#{detail[:tool]} not allowed for sub-agents"
        when :steps_exceeded
          "Steps exceeded: requested #{detail[:requested]}, max per agent #{detail[:max_per_agent]}, " \
          "remaining budget #{detail[:remaining]}"
        end
      end

      def deconstruct_keys(_) = { type:, detail: }
    end
  end
end
