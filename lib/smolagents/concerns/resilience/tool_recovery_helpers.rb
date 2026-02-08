module Smolagents
  module Concerns
    module Resilience
      # Helper methods for tool recovery operations.
      #
      # Extracted from ToolRecovery to keep module under 100 lines.
      # Provides argument reformatting, fallback execution, result building,
      # and event emission.
      #
      # @api private
      module ToolRecoveryHelpers
        private

        def reformat_arguments(_tool, arguments, _error)
          arguments.transform_values do |v|
            case v
            when String then v.strip
            when Numeric then v
            else v.to_s
            end
          end
        end

        def try_fallback_tool(tool, arguments, original_error)
          fallback_name = tool_recovery_config.fallback_for(tool.name)
          fallback_tool = @tools&.[](fallback_name)

          return build_failure_result(original_error, 1, "No fallback tool") unless fallback_tool

          begin
            result = execute_tool_directly(fallback_tool, arguments)
            build_success_result(result, 1, action: Types::RecoveryAction::SWITCH)
          rescue StandardError => e
            build_failure_result(e, 1, "Fallback also failed")
          end
        end

        def wrap_direct_execution(tool, arguments)
          result = execute_tool_directly(tool, arguments)
          build_success_result(result, 1)
        rescue StandardError => e
          build_failure_result(e, 1)
        end

        def execute_tool_directly(tool, arguments)
          tool.execute(**arguments.transform_keys(&:to_sym))
        end

        def build_success_result(result, attempts, action: Types::RecoveryAction::RETRY)
          Types::ToolRecoveryResult.success(result, attempts:, action:)
        end

        def build_failure_result(error, attempts, reason = nil)
          Types::ToolRecoveryResult.failure(error, attempts:, reason:)
        end

        def emit_recovery_attempt(tool_name, action, attempt, error)
          emit :tool_recovery_attempted,
               tool_name:,
               action:,
               attempt:,
               error_class: error.class.name,
               error_message: error.message
        end

        def emit_recovery_success(tool_name, attempts)
          emit :tool_recovery_succeeded, tool_name:, attempts:
        end

        def run_recovery_loop(tool, arguments)
          state = { attempt: 0, last_error: nil, current_args: arguments }
          while state[:attempt] < tool_recovery_config.max_attempts
            result = execute_attempt(tool, arguments, state)
            return result if result
          end
          build_failure_result(state[:last_error], state[:attempt])
        end

        def execute_attempt(tool, original_args, state)
          state[:attempt] += 1
          result = try_single_attempt(tool, state[:current_args], state[:attempt])
          return result if result.is_a?(Types::ToolRecoveryResult) && result.success?

          handle_failed_attempt(tool, result, original_args, state)
        end

        def handle_failed_attempt(tool, error, original_args, state)
          last_error, new_args, action = handle_attempt_error(tool, error, state[:current_args], state[:attempt])
          state[:last_error] = last_error
          state[:current_args] = new_args
          return try_fallback_tool(tool, original_args, last_error) if action == :switch

          false if action
        end
      end
    end
  end
end
