module Smolagents
  module Types
    # Actions for tool execution recovery (PALADIN pattern).
    #
    # PALADIN research demonstrated 89.68% recovery rates using structured
    # recovery actions. This module defines the actions available for
    # recovering from tool execution failures.
    #
    # @example Checking action validity
    #   RecoveryAction.valid?(:retry)     # => true
    #   RecoveryAction.valid?(:invalid)   # => false
    #
    # @see ToolRecovery For the recovery implementation
    module RecoveryAction
      # Retry the same tool call (for transient errors)
      RETRY = :retry

      # Reformat arguments and retry (for ArgumentError)
      REFORMAT = :reformat

      # Try alternative/fallback tool
      SWITCH = :switch

      # Give up, report error
      TERMINATE = :terminate

      # All valid recovery actions
      ALL = [RETRY, REFORMAT, SWITCH, TERMINATE].freeze

      # Check if an action is valid.
      #
      # @param action [Symbol] The action to check
      # @return [Boolean] True if the action is valid
      def self.valid?(action) = ALL.include?(action)
    end
  end
end
