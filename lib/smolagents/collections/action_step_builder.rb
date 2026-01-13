module Smolagents
  module Collections
    # Mutable builder for constructing ActionStep instances.
    #
    # ActionStepBuilder collects step data during execution and produces
    # an immutable ActionStep when complete. Automatically initializes
    # timing and generates a trace ID.
    #
    # @example Building an action step
    #   builder = ActionStepBuilder.new(step_number: 0)
    #   builder.model_output_message = model_response
    #   builder.tool_calls = parsed_calls
    #   builder.observations = "Tool returned: ..."
    #   step = builder.build
    #
    # @see Types::ActionStep The immutable step type produced by build
    class ActionStepBuilder
      # @return [Integer] Current step number
      attr_accessor :step_number
      # @return [Types::Timing] Execution timing tracker
      attr_accessor :timing
      # @return [ChatMessage, nil] Model's output message
      attr_accessor :model_output_message
      # @return [Array<Types::ToolCall>, nil] Tool calls from this step
      attr_accessor :tool_calls
      # @return [Exception, String, nil] Any error that occurred
      attr_accessor :error
      # @return [String, nil] Code action (for Code agents)
      attr_accessor :code_action
      # @return [String, nil] Observations from tool execution
      attr_accessor :observations
      # @return [Array<String>, nil] Images from observations
      attr_accessor :observations_images
      # @return [Object, nil] Direct output from action
      attr_accessor :action_output
      # @return [Types::TokenUsage, nil] Token usage for this step
      attr_accessor :token_usage
      # @return [Boolean] Whether this step contains the final answer
      attr_accessor :is_final_answer
      # @return [String] Unique trace identifier
      attr_accessor :trace_id
      # @return [String, nil] Parent trace for hierarchical tracing
      attr_accessor :parent_trace_id

      # Creates a new builder for the given step number.
      #
      # @param step_number [Integer] The step number to assign
      # @param trace_id [String, nil] Optional trace ID (auto-generated if nil)
      # @param parent_trace_id [String, nil] Optional parent trace ID
      def initialize(step_number:, trace_id: nil, parent_trace_id: nil)
        @step_number = step_number
        @timing = Types::Timing.start_now
        @is_final_answer = false
        @observations_images = nil
        @trace_id = trace_id || generate_trace_id
        @parent_trace_id = parent_trace_id
      end

      # Builds an immutable ActionStep from the current state.
      # @return [Types::ActionStep] The completed action step
      def build
        Types::ActionStep.new(step_number:, timing:, model_output_message:, tool_calls:, error:,
                              code_action:, observations:, observations_images:, action_output:,
                              token_usage:, is_final_answer:, trace_id:, parent_trace_id:)
      end

      private

      def generate_trace_id = SecureRandom.uuid
    end
  end
end
