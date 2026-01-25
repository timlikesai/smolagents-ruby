module Smolagents
  module Concerns
    # Goal-aware early yield for parallel tool execution.
    #
    # Combines EarlyYield with GoalTracking to create quality predicates
    # that consider whether a result advances the current goal.
    #
    # When multiple tools are called in parallel, this allows returning
    # early when a result is "good enough" for the current goal, rather
    # than waiting for all results.
    #
    # @example Basic usage
    #   results = execute_tools_for_goal(tool_calls)
    #   # Returns early when a result advances the goal
    #
    # @example With custom quality check
    #   results = execute_tools_for_goal(tool_calls) do |result, goal|
    #     result_contains_answer?(result, goal.description)
    #   end
    #
    # @see EarlyYield For base early yield functionality
    # @see GoalTracking For goal management
    module GoalAwareYield
      # Execute tool calls with goal-aware early yield.
      #
      # Returns early when a result appears to advance the current goal.
      # Falls back to standard execution if no goal or single tool call.
      #
      # @param tool_calls [Array<ToolCall>] Tool calls to execute
      # @yield [result, goal] Optional custom quality predicate
      # @yieldparam result [Object] Tool execution result
      # @yieldparam goal [Types::Goal] Current goal
      # @yieldreturn [Boolean] true if result is good enough
      # @return [Types::EarlyYieldResult] Results with early yield metadata
      def execute_tools_for_goal(tool_calls, &)
        goal = respond_to?(:current_goal) ? current_goal : nil

        # No goal or no early yield support - use standard execution
        return execute_standard(tool_calls) unless goal && respond_to?(:execute_with_early_yield)

        predicate = build_goal_predicate(goal, &)
        execute_with_early_yield(tool_calls, &predicate)
      end

      private

      # Execute without early yield optimization.
      # @param tool_calls [Array<ToolCall>] Tool calls
      # @return [Types::EarlyYieldResult] Wrapped results
      def execute_standard(tool_calls)
        results = tool_calls.map { |tc| execute_tool_call(tc) }
        wrap_as_early_yield_result(results)
      end

      # Wrap results in EarlyYieldResult format for consistent interface.
      # @param results [Array] Tool results
      # @return [Types::EarlyYieldResult]
      def wrap_as_early_yield_result(results)
        Types::EarlyYieldResult.new(
          results:,
          early_result: results.first,
          pending_count: 0,
          collector: nil
        )
      end

      # Build quality predicate from goal context.
      # @param goal [Types::Goal] Current goal
      # @yield [result, goal] Optional custom predicate
      # @return [Proc] Quality predicate for early yield
      def build_goal_predicate(goal, &)
        if block_given?
          ->(result) { yield(result, goal) }
        else
          ->(result) { result_advances_goal?(result, goal) }
        end
      end

      # Default heuristic: does result appear to advance the goal?
      #
      # Checks if the result contains substantive content that
      # might help achieve the goal. Override for domain-specific logic.
      #
      # @param result [Object] Tool execution result
      # @param goal [Types::Goal] Current goal
      # @return [Boolean] true if result seems useful
      def result_advances_goal?(result, goal)
        return false unless result
        return false unless goal&.active?

        output = extract_output(result)
        return false if output.nil? || output.empty?

        # Basic heuristic: non-trivial output that doesn't look like an error
        output.length > 20 && !looks_like_error?(output)
      end

      # Extract string output from various result types.
      # @param result [Object] Tool result
      # @return [String, nil]
      def extract_output(result)
        case result
        when String then result
        when Hash then result[:output]&.to_s || result["output"]&.to_s
        else
          result.respond_to?(:output) ? result.output.to_s : result.to_s
        end
      end

      # Check if output looks like an error message.
      # @param output [String] Output text
      # @return [Boolean]
      def looks_like_error?(output)
        output.match?(/\b(error|exception|failed|not found|invalid)\b/i)
      end
    end
  end
end
