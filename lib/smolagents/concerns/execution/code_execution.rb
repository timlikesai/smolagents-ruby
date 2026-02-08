require "digest"

module Smolagents
  module Concerns
    # Ruby code execution for agents.
    #
    # Orchestrates the complete code execution pipeline for code-writing agents:
    # 1. Generate code from the model ({CodeGeneration})
    # 2. Parse/extract code blocks ({CodeParsing})
    # 3. Execute in sandbox with proper context ({ExecutionContext})
    #
    # == Events Emitted
    #
    # - {Events::CodeExecution} (phase: :generated) - When code is extracted from model response
    # - {Events::CodeExecution} (phase: :started) - Before sandbox execution begins
    # - {Events::CodeExecution} (phase: :finished) - After sandbox execution completes
    #
    # @see CodeGeneration For model to code generation
    # @see CodeParsing For code block extraction
    # @see ExecutionContext For variable scope management
    # @see CodeHints For contextual hints
    # @see BudgetTracking For step budget reminders
    # @see ObservationBuilder For observation formatting
    module CodeExecution
      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
        base.include(CodeGeneration)
        base.include(CodeParsing)
        base.include(ExecutionContext)
        base.include(CodeHints)
        base.include(BudgetTracking)
        base.include(ObservationBuilder)
        base.include(ParseRetry)
      end

      # Execute a step by generating and running Ruby code.
      #
      # @param action_step [ActionStep] Step to update with results
      # @return [void]
      def execute_step(action_step)
        response = generate_code_response(action_step)
        result = extract_code_from_response(action_step, response)

        unless result.success?
          return unless can_retry_parse?(action_step, result)

          response = generate_code_response(action_step)
          result = extract_code_from_response(action_step, response)
          return unless result.success?
        end

        emit_code_generated(result.code, action_step)
        execute_code_action(action_step, result.code)
      end

      private

      # Execute extracted code via executor.
      #
      # @param action_step [ActionStep] Step to update
      # @param code [String] Code to execute
      # @return [void]
      def execute_code_action(action_step, code)
        action_step.code_action = code
        @executor.send_variables(build_execution_variables(action_step))
        result = execute_with_events(code)
        action_step.tool_calls = tracked_calls_to_tool_calls
        apply_execution_result(action_step, result, code)
      end

      # Execute code and emit lifecycle events.
      #
      # @param code [String] Code to execute
      # @return [Executors::ExecutionResult] Execution result
      def execute_with_events(code)
        code_hash = code_hash_for(code)
        emit :code_execution, phase: :started, code_hash:, isolation_mode: :ractor

        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = @executor.execute(code, language: :ruby, timeout: 30)
        emit_execution_finished(code_hash, result, start)
        result
      end

      # Emit completion event with outcome and timing.
      def emit_execution_finished(code_hash, result, start)
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round
        emit :code_execution, phase: :finished,
                              code_hash:,
                              outcome: result.error ? :error : :success,
                              duration_ms:,
                              output: result.output&.to_s&.slice(0, 100),
                              error_class: result.error ? "ExecutionError" : nil
      end

      # Emit code generated event.
      #
      # @param code [String] Generated code
      # @param action_step [ActionStep] Current step
      # @return [void]
      def emit_code_generated(code, action_step)
        emit :code_execution, phase: :generated,
                              code:,
                              language: :ruby,
                              step_number: action_step.step_number,
                              model_id: @model&.model_id
      end

      # Convert executor's TrackedCall records to ToolCall objects for the step.
      # Bridges the gap between sandbox-tracked calls and the ActionStep data model.
      #
      # @return [Array<Types::ToolCall>, nil] Tool calls or nil if none
      def tracked_calls_to_tool_calls
        return nil unless @executor.respond_to?(:tool_calls)

        calls = @executor.tool_calls
        return nil if calls.empty?

        calls.map { |tc| Types::ToolCall.new(name: tc.tool_name.to_s, arguments: tc.arguments || {}, id: nil) }
      end

      # Generate short hash for code correlation.
      #
      # @param code [String] Code to hash
      # @return [String] 8-character hash prefix
      def code_hash_for(code) = Digest::MD5.hexdigest(code)[0, 8]

      # Process execution result into action_step.
      #
      # @param action_step [ActionStep] Step to update
      # @param result [Executors::ExecutionResult] Execution result
      # @param code [String] The executed code for pattern detection
      # @return [void]
      def apply_execution_result(action_step, result, code = nil)
        case result
        in Executors::ExecutionResult[error: nil, output:, logs:, final_answer:]
          action_step.action_output = iterator_noise?(output) ? nil : output
          action_step.final_answer = final_answer
          action_step.observations = build_observations(action_step, output, logs, code, final_answer)
        in Executors::ExecutionResult[error:, logs:]
          action_step.error = error
          action_step.observations = with_budget_reminder(action_step, logs)
        end
      end
    end
  end
end
