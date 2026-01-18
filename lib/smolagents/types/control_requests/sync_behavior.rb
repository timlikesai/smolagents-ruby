module Smolagents
  module Types
    module ControlRequests
      # Sync behavior constants for control requests in sync mode.
      #
      # Determines how control requests are handled when using run() instead of run_fiber().
      module SyncBehavior
        # Raise ControlFlowError when a control request is encountered in sync mode.
        RAISE = :raise

        # Use the default value if available, or skip if no default.
        DEFAULT = :default

        # Auto-approve confirmations without user interaction.
        APPROVE = :approve

        # Skip the request and return nil.
        SKIP = :skip
      end
    end
  end
end
