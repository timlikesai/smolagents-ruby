require_relative "evaluation"
require_relative "react_loop/core"
require_relative "react_loop/execution"
require_relative "react_loop/control"
require_relative "react_loop/repetition"

module Smolagents
  module Concerns
    # Event-driven ReAct (Reason + Act) loop for agents.
    #
    # Implements the core agent execution pattern: reason about the task,
    # take an action (call a tool or generate code), observe the result,
    # and repeat until the task is complete or max_steps is reached.
    #
    # == Composition Architecture
    #
    # ReActLoop is composed of sub-concerns that can be used independently
    # or layered for additional functionality:
    #
    #   ReActLoop (auto-includes Core, Execution)
    #       |
    #       +-- Core: setup_agent, run, run_fiber, memory access
    #       |
    #       +-- Execution: fiber_loop, run_steps, step monitoring
    #               |
    #               +-- Completion: finalize, build_result
    #               |
    #               +-- ErrorHandling: finalize_error
    #
    # == Opt-in Sub-concerns
    #
    # Include these AFTER ReActLoop for additional features:
    #
    #   +-- Control: request_input, request_confirmation, escalate_query
    #   |   (Overrides: consume_fiber for sync handling)
    #   |
    #   +-- Repetition: check_repetition, RepetitionResult
    #   |   (Overrides: check_and_handle_repetition stub in Execution)
    #   |
    #   +-- Evaluation: evaluate_progress, parse_evaluation
    #       (Overrides: execute_evaluation_if_needed stub in Execution)
    #
    # == Extension Points (Stubs)
    #
    # Execution provides no-op stubs that opt-in concerns override:
    #
    # - execute_planning_step_if_needed - Override by Planning
    # - execute_initial_planning_if_needed - Override by Planning
    # - check_and_handle_repetition - Override by Repetition
    # - execute_evaluation_if_needed - Override by Evaluation
    #
    # == Events Emitted
    #
    # The loop operates through an event-driven architecture:
    #
    # - {Events::StepCompleted} - Emitted after each step completes
    # - {Events::TaskCompleted} - Emitted when the task finishes (success or max_steps)
    # - {Events::ErrorOccurred} - Emitted on failures
    # - {Events::ControlYielded} - Emitted when control is yielded (Control concern)
    # - {Events::ControlResumed} - Emitted when control returns (Control concern)
    # - {Events::RepetitionDetected} - Emitted on loop detection (Repetition concern)
    # - {Events::EvaluationCompleted} - Emitted after evaluation (Evaluation concern)
    #
    # Include {Events::Consumer} to subscribe to these events.
    #
    # == Required Instance Variables
    #
    # Classes including this concern must set these via {Core#setup_agent}:
    #
    # - @tools [Hash<Symbol, Tool>] - Available tools
    # - @model [Model] - LLM for code/action generation
    # - @memory [AgentMemory] - Conversation and step history
    # - @max_steps [Integer] - Maximum steps before timeout
    # - @logger [Logger] - Logging instance
    #
    # == Required Methods
    #
    # Classes must implement:
    #
    # - step(task, step_number:) - Execute one step, return {Types::ActionStep}
    #
    # @example Basic usage (Core + Execution only)
    #   class SimpleAgent
    #     include Smolagents::Concerns::ReActLoop
    #
    #     def step(task, step_number:)
    #       # Implement step logic - generate code or call tools
    #     end
    #   end
    #
    # @example Full-featured agent with all opt-ins
    #   class FullAgent
    #     include Smolagents::Concerns::ReActLoop
    #     include Smolagents::Concerns::ReActLoop::Control    # Must come after ReActLoop
    #     include Smolagents::Concerns::ReActLoop::Repetition # Must come after ReActLoop
    #     include Smolagents::Concerns::Evaluation            # Must come after ReActLoop
    #   end
    #
    # @example Fiber-based bidirectional control (requires Control)
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
    #
    # @example Streaming execution with step-by-step processing
    #   agent.run("Analyze this data", stream: true).each do |step|
    #     puts "Step #{step.step_number}: #{step.observations}"
    #   end
    #
    # @see Core For setup_agent and run entry points
    # @see Execution For the main loop and step monitoring
    # @see Completion For result building
    # @see ErrorHandling For error recovery
    # @see Control For Fiber-based bidirectional control flow
    # @see Repetition For loop detection and stuck agent handling
    # @see Evaluation For metacognition after steps
    # @see Agents::AgentRuntime For a complete implementation
    module ReActLoop
      def self.included(base)
        base.include(Events::Emitter) unless base < Events::Emitter
        base.include(Events::Consumer) unless base < Events::Consumer
        base.include(Core)
        base.include(Execution)
        base.attr_reader :tools, :model, :memory, :max_steps, :logger, :state
      end

      # Re-export types for backwards compatibility
      RepetitionResult = Repetition::RepetitionResult
      RepetitionConfig = Repetition::RepetitionConfig
    end
  end
end
