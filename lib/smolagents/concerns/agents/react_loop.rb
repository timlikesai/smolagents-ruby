require_relative "evaluation"
require_relative "react_loop/setup"
require_relative "react_loop/execution"
require_relative "react_loop/step_monitoring"
require_relative "react_loop/result_builder"
require_relative "react_loop/event_emitter"
require_relative "react_loop/control"

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
    # @example Fiber-based bidirectional control
    #   fiber = agent.run_fiber("Find Ruby 4.0 features")
    #   loop do
    #     result = fiber.resume
    #     case result
    #     in Types::ControlRequests::UserInput => req
    #       fiber.resume(Types::ControlRequests::Response.respond(request_id: req.id, value: gets.chomp))
    #     in Types::RunResult => final
    #       break final
    #     end
    #   end
    module ReActLoop
      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
        base.include(Events::Consumer) unless base < Events::Consumer
        base.include(Evaluation)
        base.include(Setup)
        base.include(Execution)
        base.include(StepMonitoring)
        base.include(ResultBuilder)
        base.include(EventEmitter)
        base.include(Control)
        base.attr_reader :tools, :model, :memory, :max_steps, :logger, :state
      end
    end
  end
end
