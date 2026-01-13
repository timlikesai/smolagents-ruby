module Smolagents
  module Collections
    # Mutable builder for constructing ActionStep instances.
    #
    # ActionStepBuilder collects step data during agent execution (tool calls,
    # observations, code execution results, etc.) and produces an immutable
    # ActionStep when complete. Automatically handles timing, trace IDs, and
    # hierarchical tracing for distributed execution.
    #
    # Used internally by agents during step execution to accumulate data before
    # creating the immutable step object that gets stored in memory.
    #
    # @example Building an action step
    #   builder = ActionStepBuilder.new(step_number: 0)
    #   builder.model_output_message = model_response
    #   builder.tool_calls = parsed_calls
    #   builder.observations = "Tool returned: ..."
    #   builder.token_usage = Types::TokenUsage.new(input: 150, output: 50)
    #   step = builder.build
    #   # => Types::ActionStep(step_number: 0, ...)
    #
    # @see Types::ActionStep The immutable step type produced by build
    # @see Collections::AgentMemory Where built steps are stored
    # @see Agents::Agent Uses this internally for step execution
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
      # Initializes a mutable builder with timing started immediately and a
      # unique trace ID. Parent trace ID can be specified for distributed tracing.
      #
      # @param step_number [Integer] The step number to assign (0-indexed)
      # @param trace_id [String, nil] Optional trace ID for this step (auto-generated as UUID if nil)
      # @param parent_trace_id [String, nil] Optional parent trace ID for hierarchical tracing
      #
      # @example Creating a builder
      #   builder = ActionStepBuilder.new(step_number: 0)
      #   # Timing started, trace_id auto-generated
      #
      # @example With hierarchical tracing
      #   builder = ActionStepBuilder.new(
      #     step_number: 1,
      #     parent_trace_id: parent_trace_id
      #   )
      #
      # @see Types::Timing Execution timing tracking
      # @see #build Create the immutable ActionStep
      def initialize(step_number:, trace_id: nil, parent_trace_id: nil)
        @step_number = step_number
        @timing = Types::Timing.start_now
        @is_final_answer = false
        @observations_images = nil
        @trace_id = trace_id || generate_trace_id
        @parent_trace_id = parent_trace_id
      end

      # Builds an immutable ActionStep from the current state.
      #
      # Creates a frozen Types::ActionStep instance with all the data accumulated
      # in this builder. The timing is finalized at build time. All attributes
      # are captured (even nil values) to preserve complete execution state.
      #
      # @return [Types::ActionStep] The completed immutable action step with all data
      #
      # @example Building a step
      #   builder = ActionStepBuilder.new(step_number: 0)
      #   builder.observations = "Result: 42"
      #   step = builder.build
      #   step.is_a?(Types::ActionStep)  # => true
      #   step.observations             # => "Result: 42"
      #
      # @see Types::ActionStep Immutable step representation
      # @see Types::Timing Timing information in the step
      # @see Collections::AgentMemory Where built steps are stored
      def build
        Types::ActionStep.new(step_number:, timing:, model_output_message:, tool_calls:, error:,
                              code_action:, observations:, observations_images:, action_output:,
                              token_usage:, is_final_answer:, trace_id:, parent_trace_id:)
      end

      private

      # Generate a unique trace ID (UUID v4).
      #
      # Used for distributed tracing and request correlation. Each step gets
      # a unique identifier for tracking across distributed systems.
      #
      # @return [String] UUID v4 string
      #
      # @api private
      def generate_trace_id = SecureRandom.uuid
    end
  end
end
