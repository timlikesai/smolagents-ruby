require_relative "control/fiber_control"
require_relative "control/user_input"
require_relative "control/confirmation"
require_relative "control/escalation"
require_relative "control/sync_handler"

module Smolagents
  module Concerns
    module ReActLoop
      # Bidirectional Fiber control flow for user input, confirmation, and escalation.
      #
      # This concern enables agents to pause execution and request external input.
      # It requires Fiber-based execution via {Core#run_fiber} to function.
      #
      # == Sub-modules
      #
      # - {Control::FiberControl} - Fiber context management
      # - {Control::UserInput} - User input requests
      # - {Control::Confirmation} - Confirmation dialogs
      # - {Control::Escalation} - Sub-agent escalation
      # - {Control::SyncHandler} - Sync mode auto-handling
      #
      # == Control Flow Pattern
      #
      # When an agent needs external input, it:
      # 1. Creates a control request (UserInput, Confirmation, or SubAgentQuery)
      # 2. Yields the request via Fiber.yield
      # 3. Receives a Response when the Fiber is resumed
      # 4. Continues execution with the response value
      #
      # == Sync Mode Behavior
      #
      # When using {Core#run} (sync mode), control requests are auto-handled
      # based on their sync_behavior setting:
      # - :approve - Auto-approve confirmations
      # - :default - Use default_value if available
      # - :skip - Skip with nil value
      #
      # @see Core#run_fiber For Fiber-based execution
      # @see Types::ControlRequests For request/response types
      module Control
        # Documents all methods provided by this concern and sub-modules.
        def self.provided_methods
          {}.merge(
            Control::FiberControl.provided_methods,
            Control::UserInput.provided_methods,
            Control::Confirmation.provided_methods,
            Control::Escalation.provided_methods,
            Control::SyncHandler.provided_methods
          )
        end

        def self.included(base)
          base.include(Control::FiberControl)
          base.include(Control::UserInput)
          base.include(Control::Confirmation)
          base.include(Control::Escalation)
          base.include(Control::SyncHandler)
        end
      end
    end
  end
end
