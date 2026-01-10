# frozen_string_literal: true

module Smolagents
  # Token usage tracking for model calls.
  TokenUsage = Data.define(:input_tokens, :output_tokens) do
    def total_tokens = input_tokens + output_tokens
    def to_h = { input_tokens: input_tokens, output_tokens: output_tokens, total_tokens: total_tokens }
  end

  # Timing information for operations.
  Timing = Data.define(:start_time, :end_time) do
    def self.start_now = new(start_time: Time.now, end_time: nil)
    def stop = self.class.new(start_time: start_time, end_time: Time.now)
    def duration = end_time && (end_time - start_time)
    def to_h = { start_time: start_time, end_time: end_time, duration: duration }
  end

  # Represents a tool call with its arguments.
  ToolCall = Data.define(:name, :arguments, :id) do
    def to_h = { id: id, type: "function", function: { name: name, arguments: arguments } }
  end

  # Output from code execution.
  CodeOutput = Data.define(:output, :logs, :is_final_answer) do
    def to_h = { output: output, logs: logs, is_final_answer: is_final_answer }
  end

  # Output from an action step.
  ActionOutput = Data.define(:output, :is_final_answer) do
    def to_h = { output: output, is_final_answer: is_final_answer }
  end

  # Output from a tool execution.
  ToolOutput = Data.define(:id, :output, :is_final_answer, :observation, :tool_call) do
    def to_h = { id: id, output: output, is_final_answer: is_final_answer, observation: observation, tool_call: tool_call&.to_h }
  end

  # Result from running an agent.
  RunResult = Data.define(:output, :state, :steps, :token_usage, :timing) do
    def success? = state == :success
    def to_h = { output: output, state: state, steps: steps, token_usage: token_usage&.to_h, timing: timing&.to_h }
  end
end
