# frozen_string_literal: true

module Smolagents
  # Token usage tracking for model calls.
  # @!attribute [r] input_tokens
  #   @return [Integer] number of input tokens
  # @!attribute [r] output_tokens
  #   @return [Integer] number of output tokens
  TokenUsage = Data.define(:input_tokens, :output_tokens) do
    # @return [Integer] total tokens used (input + output)
    def total_tokens
      input_tokens + output_tokens
    end

    # @return [Hash] dictionary representation
    def to_h
      {
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        total_tokens: total_tokens
      }
    end
  end

  # Timing information for operations.
  # @!attribute [r] start_time
  #   @return [Time] when the operation started
  # @!attribute [r] end_time
  #   @return [Time, nil] when the operation ended (nil if not yet completed)
  Timing = Data.define(:start_time, :end_time) do
    # Create a new Timing starting now.
    # @return [Timing]
    def self.start_now
      new(start_time: Time.now, end_time: nil)
    end

    # Stop timing and return new Timing with end_time set.
    # @return [Timing]
    def stop
      self.class.new(start_time: start_time, end_time: Time.now)
    end

    # Calculate duration in seconds.
    # @return [Float, nil] duration in seconds, or nil if not yet stopped
    def duration
      return nil unless end_time

      end_time - start_time
    end

    # @return [Hash] dictionary representation
    def to_h
      {
        start_time: start_time,
        end_time: end_time,
        duration: duration
      }
    end
  end

  # Represents a tool call with its arguments.
  # @!attribute [r] name
  #   @return [String] tool name
  # @!attribute [r] arguments
  #   @return [Hash] tool arguments
  # @!attribute [r] id
  #   @return [String] unique identifier for this tool call
  ToolCall = Data.define(:name, :arguments, :id) do
    # @return [Hash] dictionary representation suitable for API calls
    def to_h
      {
        id: id,
        type: "function",
        function: {
          name: name,
          arguments: arguments
        }
      }
    end
  end

  # Output from code execution.
  # @!attribute [r] output
  #   @return [Object] the result of the code execution
  # @!attribute [r] logs
  #   @return [String] captured output (puts/print statements)
  # @!attribute [r] is_final_answer
  #   @return [Boolean] whether final_answer was called
  CodeOutput = Data.define(:output, :logs, :is_final_answer) do
    # @return [Hash] dictionary representation
    def to_h
      {
        output: output,
        logs: logs,
        is_final_answer: is_final_answer
      }
    end
  end

  # Output from an action step.
  # @!attribute [r] output
  #   @return [Object] the result of the action
  # @!attribute [r] is_final_answer
  #   @return [Boolean] whether this is the final answer
  ActionOutput = Data.define(:output, :is_final_answer) do
    # @return [Hash] dictionary representation
    def to_h
      {
        output: output,
        is_final_answer: is_final_answer
      }
    end
  end

  # Output from a tool execution.
  # @!attribute [r] id
  #   @return [String] tool call ID
  # @!attribute [r] output
  #   @return [Object] tool result
  # @!attribute [r] is_final_answer
  #   @return [Boolean] whether this is the final answer
  # @!attribute [r] observation
  #   @return [String] observation/logs from execution
  # @!attribute [r] tool_call
  #   @return [ToolCall] the original tool call
  ToolOutput = Data.define(:id, :output, :is_final_answer, :observation, :tool_call) do
    # @return [Hash] dictionary representation
    def to_h
      {
        id: id,
        output: output,
        is_final_answer: is_final_answer,
        observation: observation,
        tool_call: tool_call&.to_h
      }
    end
  end

  # Result from running an agent.
  # @!attribute [r] output
  #   @return [Object, nil] the final output
  # @!attribute [r] state
  #   @return [Symbol] :success or :max_steps_error
  # @!attribute [r] steps
  #   @return [Array<Hash>] step history
  # @!attribute [r] token_usage
  #   @return [TokenUsage, nil] aggregate token usage
  # @!attribute [r] timing
  #   @return [Timing, nil] total timing
  RunResult = Data.define(:output, :state, :steps, :token_usage, :timing) do
    # @return [Boolean] whether the run was successful
    def success?
      state == :success
    end

    # @return [Hash] dictionary representation
    def to_h
      {
        output: output,
        state: state,
        steps: steps,
        token_usage: token_usage&.to_h,
        timing: timing&.to_h
      }
    end
  end
end
