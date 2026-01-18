module Smolagents
  module Types
    module ControlRequests
      # Sync behavior constants for control requests in sync mode.
      #
      # Determines how control requests are handled when using run() instead of run_fiber().
      module SyncBehavior
        RAISE = :raise      # Raise ControlFlowError (current behavior)
        DEFAULT = :default  # Use default value if available
        APPROVE = :approve  # Auto-approve confirmations
        SKIP = :skip        # Skip and return nil
      end
    end
  end
end
