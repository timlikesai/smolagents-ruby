module Smolagents
  module Types
    # Immutable token usage statistics from an LLM response.
    #
    # Tracks input and output tokens for billing, optimization, and cost analysis.
    # Supports accumulation across multiple steps via addition.
    #
    # @example Tracking token usage
    #   usage = Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
    #   usage.total_tokens  # => 150
    #
    # @example Accumulating usage across steps
    #   total = Types::TokenUsage.zero
    #   steps.each { |step| total = total + step.token_usage }
    #   total.total_tokens  # => sum of all tokens
    #
    # @see ChatMessage#token_usage For usage in messages
    # @see ActionStep#token_usage For step-level tracking
    TokenUsage = Data.define(:input_tokens, :output_tokens) do
      # Creates a zero-initialized TokenUsage.
      #
      # @return [TokenUsage] Usage with 0 input and output tokens
      # @example
      #   TokenUsage.zero  # => #<TokenUsage input_tokens=0, output_tokens=0>
      def self.zero = new(input_tokens: 0, output_tokens: 0)

      # Adds two token usage objects together.
      #
      # @param other [TokenUsage] Another usage to add
      # @return [TokenUsage] New usage with summed tokens
      # @raise [TypeError] If other is not TokenUsage
      # @example
      #   usage1 = TokenUsage.new(input_tokens: 100, output_tokens: 50)
      #   usage2 = TokenUsage.new(input_tokens: 75, output_tokens: 25)
      #   total = usage1 + usage2  # => TokenUsage(175, 75)
      def +(other)
        self.class.new(input_tokens: input_tokens + other.input_tokens,
                       output_tokens: output_tokens + other.output_tokens)
      end

      # Calculates total token count (input + output).
      #
      # @return [Integer] Sum of input and output tokens
      # @example
      #   usage.total_tokens  # => 150
      def total_tokens = input_tokens + output_tokens

      # Converts to hash for serialization.
      #
      # @return [Hash] Hash with :input_tokens, :output_tokens, :total_tokens
      # @example
      #   usage.to_h  # => { input_tokens: 100, output_tokens: 50, total_tokens: 150 }
      def to_h = { input_tokens:, output_tokens:, total_tokens: }
    end

    # Immutable timing information for an operation.
    #
    # Records when an operation started and stopped, with convenient methods
    # for measuring duration. Used throughout the system for performance monitoring.
    #
    # @example Timing an operation
    #   timing = Types::Timing.start_now
    #   # ... do work ...
    #   timing = timing.stop
    #   timing.duration  # => 1.234 (seconds)
    #
    # @see ActionStep#timing For step-level timing
    # @see ExecutionOutcome#duration For operation duration
    Timing = Data.define(:start_time, :end_time) do
      # Creates a Timing with current time as start and nil end.
      #
      # @return [Timing] Timing starting now, not yet stopped
      # @example
      #   timing = Timing.start_now  # => Timing(start_time: Time.now, end_time: nil)
      def self.start_now = new(start_time: Time.now, end_time: nil)

      # Marks the end time as now, returning a new Timing.
      #
      # @return [Timing] New timing with end_time set to current time
      # @example
      #   timing = Timing.start_now.stop  # => Timing with both times set
      def stop = self.class.new(start_time:, end_time: Time.now)

      # Calculates elapsed time in seconds.
      #
      # @return [Float, nil] Duration in seconds, or nil if not stopped
      # @example
      #   timing = Timing.start_now.stop
      #   timing.duration  # => 1.234 (seconds)
      def duration = end_time && (end_time - start_time)

      # Converts to hash for serialization.
      #
      # @return [Hash] Hash with :start_time, :end_time, :duration
      # @example
      #   timing.to_h  # => { start_time: ..., end_time: ..., duration: 1.234 }
      def to_h = { start_time:, end_time:, duration: }
    end

    # Immutable context tracking a run's progress.
    #
    # Maintains the current step number, cumulative token usage, and timing
    # information throughout an agent run. Enables progress tracking and
    # limit checking (max steps, max tokens).
    #
    # @example Tracking run progress
    #   context = Types::RunContext.start
    #   context = context.advance.add_tokens(usage)
    #   context.steps_completed  # => 1
    #
    # @see ExecutionOutcome For run result tracking
    # @see Agents#run Uses this to track progress
    RunContext = Data.define(:step_number, :total_tokens, :timing) do
      # Creates a RunContext starting at step 1 with zero tokens.
      #
      # @return [RunContext] Context ready for execution
      # @example
      #   context = RunContext.start  # => RunContext(step_number: 1, total_tokens: 0, timing: ...)
      def self.start = new(step_number: 1, total_tokens: TokenUsage.zero, timing: Timing.start_now)

      # Advances to the next step.
      #
      # @return [RunContext] New context with incremented step_number
      # @example
      #   context = context.advance  # => step_number increases by 1
      def advance = with(step_number: step_number + 1)

      # Adds token usage to the running total.
      #
      # @param usage [TokenUsage, nil] Tokens to add
      # @return [RunContext] New context with updated total_tokens (unchanged if usage is nil)
      # @example
      #   context = context.add_tokens(TokenUsage.new(100, 50))
      def add_tokens(usage) = usage ? with(total_tokens: total_tokens + usage) : self

      # Marks the run as finished.
      #
      # @return [RunContext] New context with timing stopped
      # @example
      #   context = context.finish  # => timing.end_time is now set
      def finish = with(timing: timing.stop)

      # Checks if step count exceeds maximum.
      #
      # @param max_steps [Integer] Maximum allowed steps
      # @return [Boolean] True if current step exceeds max
      # @example
      #   context.exceeded?(10)  # => true if step_number > 10
      def exceeded?(max_steps) = step_number > max_steps

      # Calculates how many steps have completed (not including current).
      #
      # @return [Integer] Number of completed steps
      # @example
      #   context.step_number = 5
      #   context.steps_completed  # => 4
      def steps_completed = step_number - 1
    end

    # Immutable representation of a tool call from the LLM.
    #
    # Represents a single tool invocation with its name, arguments, and
    # unique ID for linking with tool responses. Used in tool-calling
    # agent architectures.
    #
    # @example Creating a tool call
    #   call = Types::ToolCall.new(
    #     name: "search",
    #     arguments: { query: "Ruby 4.0" },
    #     id: "call_123"
    #   )
    #
    # @see ChatMessage#tool_calls For tool calls in messages
    # @see ToolOutput For tool execution results
    ToolCall = Data.define(:name, :arguments, :id) do
      # Converts tool call to hash in OpenAI function calling format.
      #
      # @return [Hash] Hash with :id, :type (always "function"), and :function (name and arguments)
      # @example
      #   call.to_h
      #   # => { id: "call_123", type: "function", function: { name: "search", arguments: {...} } }
      def to_h = { id:, type: "function", function: { name:, arguments: } }
    end

    # Immutable result from executing a tool.
    #
    # Wraps the output from tool execution with metadata about success,
    # observations, and whether the tool call produced a final answer.
    # Links back to the original ToolCall via ID.
    #
    # @example Creating tool output from successful call
    #   output = Types::ToolOutput.from_call(
    #     tool_call,
    #     output: "Found 10 results",
    #     observation: "Search completed"
    #   )
    #
    # @example Creating tool output for errors
    #   error_output = Types::ToolOutput.error(id: "call_123", observation: "Tool not found")
    #
    # @see ToolCall For the original call
    # @see ActionStep#action_output For step-level output
    ToolOutput = Data.define(:id, :output, :is_final_answer, :observation, :tool_call) do
      # Creates ToolOutput from a successful tool call.
      #
      # @param tool_call [ToolCall] The original tool call
      # @param output [String] The tool's output/result
      # @param observation [String] Observation about the execution
      # @param is_final [Boolean] Whether this is a final answer
      # @return [ToolOutput] Result wrapping the output
      # @example
      #   ToolOutput.from_call(call, output: "result", observation: "completed")
      def self.from_call(tool_call, output:, observation:, is_final: false)
        new(id: tool_call.id, output:, is_final_answer: is_final, observation:, tool_call:)
      end

      # Creates ToolOutput representing a tool error.
      #
      # @param id [String] ID linking to original ToolCall
      # @param observation [String] Error message or description
      # @return [ToolOutput] Error result with nil output
      # @example
      #   ToolOutput.error(id: "call_123", observation: "Tool failed: not found")
      def self.error(id:, observation:)
        new(id:, output: nil, is_final_answer: false, observation:, tool_call: nil)
      end

      # Converts to hash for serialization.
      #
      # @return [Hash] Hash with :id, :output, :is_final_answer, :observation, :tool_call
      # @example
      #   output.to_h  # => { id: "call_123", output: "...", is_final_answer: false, ... }
      def to_h = { id:, output:, is_final_answer:, observation:, tool_call: tool_call&.to_h }
    end

    # Immutable result from running an agent task.
    #
    # Represents the complete result of an agent task execution, including
    # the final output, outcome state, all steps taken, token usage, and timing.
    # Provides convenience methods for checking outcome and analyzing performance.
    #
    # @example Checking run result
    #   result = agent.run("Calculate 2+2")
    #   if result.success?
    #     puts result.output
    #   elsif result.max_steps?
    #     puts "Agent exceeded step limit"
    #   end
    #
    # @example Analyzing performance
    #   puts "Duration: #{result.duration}s"
    #   puts "Steps: #{result.step_count}"
    #   puts "Tokens: #{result.token_usage.total_tokens}"
    #
    # @see Agents#run Returns this type
    # @see ExecutionOutcome For event-driven result handling
    RunResult = Data.define(:output, :state, :steps, :token_usage, :timing) do
      # Checks if task completed successfully.
      #
      # @return [Boolean] True if state is :success
      # @example
      #   result.success?  # => true
      def success? = Outcome.success?(state)

      # Checks if task partially succeeded.
      #
      # @return [Boolean] True if state is :partial
      # @example
      #   result.partial?  # => true if partial credit
      def partial? = Outcome.partial?(state)

      # Checks if task failed completely.
      #
      # @return [Boolean] True if state is :failure
      # @example
      #   result.failure?  # => true if failed
      def failure? = Outcome.failure?(state)

      # Checks if task ended with error.
      #
      # @return [Boolean] True if state is :error
      # @example
      #   result.error?  # => true if exception occurred
      def error? = Outcome.error?(state)

      # Checks if agent exceeded step limit.
      #
      # @return [Boolean] True if state is :max_steps_reached
      # @example
      #   result.max_steps?  # => true if ran out of steps
      def max_steps? = Outcome.max_steps?(state)

      # Checks if task execution timed out.
      #
      # @return [Boolean] True if state is :timeout
      # @example
      #   result.timeout?  # => true if execution timed out
      def timeout? = Outcome.timeout?(state)

      # Checks if task is in a terminal state.
      #
      # @return [Boolean] True if state is success, failure, error, or timeout
      # @example
      #   result.terminal?  # => true if execution ended
      def terminal? = Outcome.terminal?(state)

      # Checks if task can be retried.
      #
      # @return [Boolean] True if state is partial or max_steps_reached
      # @example
      #   result.retriable?  # => true if can run again
      def retriable? = Outcome.retriable?(state)

      # Alias for outcome state.
      #
      # @return [Symbol] The outcome state (:success, :failure, :error, etc.)
      # @example
      #   result.outcome  # => :success
      def outcome = state

      # Aggregated tool usage statistics.
      #
      # Collects call counts, error rates, and timing for each tool used
      # throughout the run.
      #
      # @return [ToolStatsAggregator] Statistics by tool name
      # @example
      #   stats = result.tool_stats
      #   stats.total_tool_calls  # => 5
      def tool_stats = ToolStatsAggregator.from_steps(steps)

      # Total duration of the run in seconds.
      #
      # @return [Float, nil] Seconds elapsed, or nil if timing not captured
      # @example
      #   result.duration  # => 2.345
      def duration = timing&.duration

      # Number of action steps (excludes TaskStep, SystemPromptStep, etc.).
      #
      # @return [Integer] Count of ActionStep instances
      # @example
      #   result.step_count  # => 3
      def step_count = action_steps.count

      # Filters steps to return only ActionStep instances.
      #
      # @return [Array<ActionStep>] Only action steps from the run
      # @example
      #   result.action_steps.each { |step| puts step.step_number }
      def action_steps = steps.select { |s| s.is_a?(ActionStep) }

      # Provides timing breakdown for each action step.
      #
      # Returns an array of hashes with step number, duration, error flag,
      # and final answer flag for convenient analysis.
      #
      # @return [Array<Hash>] Hashes with :step, :duration, :has_error, :is_final
      # @example
      #   result.step_timings
      #   # => [{ step: 0, duration: 0.5, has_error: false, is_final: false }, ...]
      def step_timings
        action_steps.map do |step|
          {
            step: step.step_number,
            duration: step.timing&.duration&.round(3),
            has_error: !step.error.nil?,
            is_final: step.is_final_answer
          }
        end
      end

      # Human-readable summary of the entire run.
      #
      # Formats outcome, step count, duration, token usage, and per-step
      # breakdown with status indicators for errors and final answers.
      #
      # @return [String] Multi-line summary suitable for logging
      # @example
      #   puts result.summary
      #   # => "Run success: 3 steps in 2.34s"
      #   # => "Output: The answer is 42..."
      #   # => "Tokens: 245 (100 in, 145 out)"
      #   # => "Steps:"
      #   # => "  0: 0.5s"
      #   # => "  1: 0.8s [ERROR]"
      #   # => "  2: 1.04s [FINAL]"
      def summary
        [
          "Run #{state}: #{step_count} steps in #{duration&.round(2)}s",
          output && "Output: #{truncate_output(output)}",
          token_usage && format_tokens(token_usage),
          "Steps:",
          *step_timings.map { format_step_timing(it) }
        ].compact.join("\n")
      end

      # Converts to hash for serialization.
      #
      # @return [Hash] Hash with :output, :state, :steps, :token_usage, :timing
      # @example
      #   result.to_h  # => { output: "...", state: :success, steps: [...], ... }
      def to_h = { output:, state:, steps:, token_usage: token_usage&.to_h, timing: timing&.to_h }

      private

      def format_step_timing(step_timing)
        status = if step_timing[:is_final]
                   " [FINAL]"
                 else
                   (step_timing[:has_error] ? " [ERROR]" : "")
                 end
        "  #{step_timing[:step]}: #{step_timing[:duration]}s#{status}"
      end

      def format_tokens(token_usage)
        "Tokens: #{token_usage.total_tokens} (#{token_usage.input_tokens} in, #{token_usage.output_tokens} out)"
      end

      def truncate_output(out)
        str = out.to_s
        str.length > 100 ? "#{str.slice(0, 100)}..." : str
      end
    end
  end
end
