module Smolagents
  module Types
    # Immutable token usage statistics from an LLM response.
    #
    # @example Tracking token usage
    #   usage = Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
    #   usage.total_tokens  # => 150
    #
    # @example Accumulating usage across steps
    #   total = Types::TokenUsage.zero
    #   steps.each { |step| total = total + step.token_usage }
    TokenUsage = Data.define(:input_tokens, :output_tokens) do
      def self.zero = new(input_tokens: 0, output_tokens: 0)
      def +(other) = self.class.new(input_tokens: input_tokens + other.input_tokens, output_tokens: output_tokens + other.output_tokens)
      def total_tokens = input_tokens + output_tokens
      def to_h = { input_tokens: input_tokens, output_tokens: output_tokens, total_tokens: total_tokens }
    end

    # Immutable timing information for an operation.
    #
    # @example Timing an operation
    #   timing = Types::Timing.start_now
    #   # ... do work ...
    #   timing = timing.stop
    #   timing.duration  # => 1.234
    Timing = Data.define(:start_time, :end_time) do
      def self.start_now = new(start_time: Time.now, end_time: nil)
      def stop = self.class.new(start_time: start_time, end_time: Time.now)
      def duration = end_time && (end_time - start_time)
      def to_h = { start_time: start_time, end_time: end_time, duration: duration }
    end

    # Immutable context tracking a run's progress.
    #
    # @example Tracking run progress
    #   context = Types::RunContext.start
    #   context = context.advance.add_tokens(usage)
    #   context.steps_completed  # => 1
    RunContext = Data.define(:step_number, :total_tokens, :timing) do
      def self.start = new(step_number: 1, total_tokens: TokenUsage.zero, timing: Timing.start_now)
      def advance = with(step_number: step_number + 1)
      def add_tokens(usage) = usage ? with(total_tokens: total_tokens + usage) : self
      def finish = with(timing: timing.stop)
      def exceeded?(max_steps) = step_number > max_steps
      def steps_completed = step_number - 1
    end

    # Immutable representation of a tool call from the LLM.
    #
    # @example Creating a tool call
    #   call = Types::ToolCall.new(
    #     name: "search",
    #     arguments: { query: "Ruby 4.0" },
    #     id: "call_123"
    #   )
    ToolCall = Data.define(:name, :arguments, :id) do
      def to_h = { id: id, type: "function", function: { name: name, arguments: arguments } }
    end

    # Immutable result from executing a tool.
    #
    # @example Creating tool output
    #   output = Types::ToolOutput.from_call(
    #     tool_call,
    #     output: "Found 10 results",
    #     observation: "Search completed"
    #   )
    ToolOutput = Data.define(:id, :output, :is_final_answer, :observation, :tool_call) do
      def self.from_call(tool_call, output:, observation:, is_final: false)
        new(id: tool_call.id, output:, is_final_answer: is_final, observation:, tool_call:)
      end

      def self.error(id:, observation:)
        new(id:, output: nil, is_final_answer: false, observation:, tool_call: nil)
      end

      def to_h = { id: id, output: output, is_final_answer: is_final_answer, observation: observation, tool_call: tool_call&.to_h }
    end

    # Immutable result from running an agent task.
    #
    # @example Checking run result
    #   result = agent.run("Calculate 2+2")
    #   if result.success?
    #     puts result.output
    #   elsif result.max_steps?
    #     puts "Agent exceeded step limit"
    #   end
    RunResult = Data.define(:output, :state, :steps, :token_usage, :timing) do
      def success? = Outcome.success?(state)
      def partial? = Outcome.partial?(state)
      def failure? = Outcome.failure?(state)
      def error? = Outcome.error?(state)
      def max_steps? = Outcome.max_steps?(state)
      def timeout? = Outcome.timeout?(state)
      def terminal? = Outcome.terminal?(state)
      def retriable? = Outcome.retriable?(state)

      def outcome = state

      def tool_stats = ToolStatsAggregator.from_steps(steps)

      # Total duration of the run in seconds
      def duration = timing&.duration

      # Number of action steps (excludes TaskStep)
      def step_count = action_steps.count

      # Returns only ActionStep instances
      def action_steps = steps.select { |s| s.is_a?(ActionStep) }

      # Returns timing breakdown per step
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

      # Human-readable summary of the run
      def summary
        lines = ["Run #{state}: #{step_count} steps in #{duration&.round(2)}s"]
        lines << "Output: #{output.to_s.slice(0, 100)}#{"..." if output.to_s.length > 100}" if output
        lines << "Tokens: #{token_usage.total_tokens} (#{token_usage.input_tokens} in, #{token_usage.output_tokens} out)" if token_usage
        lines << "Steps:"
        step_timings.each do |st|
          status = if st[:is_final]
                     " [FINAL]"
                   else
                     (st[:has_error] ? " [ERROR]" : "")
                   end
          lines << "  #{st[:step]}: #{st[:duration]}s#{status}"
        end
        lines.join("\n")
      end

      def to_h = { output: output, state: state, steps: steps, token_usage: token_usage&.to_h, timing: timing&.to_h }
    end
  end
end
