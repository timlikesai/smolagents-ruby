module Smolagents
  TokenUsage = Data.define(:input_tokens, :output_tokens) do
    def self.zero = new(input_tokens: 0, output_tokens: 0)
    def +(other) = self.class.new(input_tokens: input_tokens + other.input_tokens, output_tokens: output_tokens + other.output_tokens)
    def total_tokens = input_tokens + output_tokens
    def to_h = { input_tokens: input_tokens, output_tokens: output_tokens, total_tokens: total_tokens }
  end

  Timing = Data.define(:start_time, :end_time) do
    def self.start_now = new(start_time: Time.now, end_time: nil)
    def stop = self.class.new(start_time: start_time, end_time: Time.now)
    def duration = end_time && (end_time - start_time)
    def to_h = { start_time: start_time, end_time: end_time, duration: duration }
  end

  RunContext = Data.define(:step_number, :total_tokens, :timing) do
    def self.start = new(step_number: 1, total_tokens: TokenUsage.zero, timing: Timing.start_now)
    def advance = with(step_number: step_number + 1)
    def add_tokens(usage) = usage ? with(total_tokens: total_tokens + usage) : self
    def finish = with(timing: timing.stop)
    def exceeded?(max_steps) = step_number > max_steps
    def steps_completed = step_number - 1
  end

  ToolCall = Data.define(:name, :arguments, :id) do
    def to_h = { id: id, type: "function", function: { name: name, arguments: arguments } }
  end

  ToolOutput = Data.define(:id, :output, :is_final_answer, :observation, :tool_call) do
    def self.from_call(tool_call, output:, observation:, is_final: false)
      new(id: tool_call.id, output:, is_final_answer: is_final, observation:, tool_call:)
    end

    def self.error(id:, observation:)
      new(id:, output: nil, is_final_answer: false, observation:, tool_call: nil)
    end

    def to_h = { id: id, output: output, is_final_answer: is_final_answer, observation: observation, tool_call: tool_call&.to_h }
  end

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

    def to_h = { output: output, state: state, steps: steps, token_usage: token_usage&.to_h, timing: timing&.to_h }
  end
end
