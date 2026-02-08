require_relative "tool_recovery_helpers"

module Smolagents
  module Concerns
    module Resilience
      # PALADIN-style structured recovery for tool execution.
      #
      # Implements recovery patterns from PALADIN research (89.68% recovery rate)
      # through structured retry, reformat, and fallback actions.
      #
      # @see Types::ToolRecoveryConfig For configuration options
      # @see Types::ToolRecoveryResult For recovery results
      module ToolRecovery
        include Events::Emitter
        include ToolRecoveryHelpers

        def self.included(base)
          base.attr_reader :tool_recovery_config
        end

        private

        def initialize_tool_recovery(config: nil)
          @tool_recovery_config = config || Types::ToolRecoveryConfig.default
        end

        # Execute tool with recovery.
        # @param tool [Tool] The tool to execute
        # @param arguments [Hash] Arguments to pass to the tool
        # @return [ToolRecoveryResult] Result of execution with recovery
        def execute_with_recovery(tool, arguments)
          return wrap_direct_execution(tool, arguments) if tool_recovery_config.disabled?

          run_recovery_loop(tool, arguments)
        end

        def try_single_attempt(tool, args, attempt)
          result = execute_tool_directly(tool, args)
          emit_recovery_success(tool.name, attempt) if attempt > 1
          build_success_result(result, attempt)
        rescue StandardError => e
          e
        end

        def handle_attempt_error(tool, error, args, attempt)
          action = select_recovery_action(tool, error, attempt)
          emit_recovery_attempt(tool.name, action, attempt, error)
          case action
          when Types::RecoveryAction::REFORMAT then [error, reformat_arguments(tool, args, error), false]
          when Types::RecoveryAction::SWITCH then [error, args, :switch]
          when Types::RecoveryAction::TERMINATE then [error, args, true]
          else [error, args, false]
          end
        end

        def select_recovery_action(tool, error, attempt)
          return Types::RecoveryAction::TERMINATE if attempt >= tool_recovery_config.max_attempts

          case error
          when ArgumentError
            can_reformat? ? Types::RecoveryAction::REFORMAT : Types::RecoveryAction::TERMINATE
          when Faraday::ServerError, Faraday::TimeoutError
            can_retry? ? Types::RecoveryAction::RETRY : Types::RecoveryAction::TERMINATE
          else
            select_default_action(tool)
          end
        end

        def select_default_action(tool)
          return Types::RecoveryAction::SWITCH if can_switch? && tool_recovery_config.fallback?(tool.name)

          can_retry? ? Types::RecoveryAction::RETRY : Types::RecoveryAction::TERMINATE
        end

        def can_retry? = tool_recovery_config.can_retry?
        def can_reformat? = tool_recovery_config.can_reformat?
        def can_switch? = tool_recovery_config.can_switch?
      end
    end
  end
end
