require_relative "react_loop/setup"
require_relative "react_loop/execution"
require_relative "react_loop/step_monitoring"
require_relative "react_loop/result_builder"
require_relative "react_loop/event_emitter"

module Smolagents
  module Concerns
    # Event-driven ReAct (Reason + Act) loop for agents.
    #
    # The loop operates purely through events:
    # - StepCompleted emitted after each step
    # - TaskCompleted emitted when task finishes
    # - ErrorOccurred emitted on failures
    #
    # Include Events::Consumer to subscribe to these events.
    #
    # @example Basic usage
    #   class MyAgent
    #     include Smolagents::Concerns::ReActLoop
    #
    #     def step(task, step_number:)
    #       # Implement step logic
    #     end
    #   end
    #
    module ReActLoop
      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
        base.include(Events::Consumer) unless base < Events::Consumer
        base.include(Setup)
        base.include(Execution)
        base.include(StepMonitoring)
        base.include(ResultBuilder)
        base.include(EventEmitter)
        base.attr_reader :tools, :model, :memory, :max_steps, :logger, :state
      end
    end
  end
end
