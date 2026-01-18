require_relative "runtime/accessors"
require_relative "runtime/initialization"
require_relative "runtime/step_execution"

module Smolagents
  module Agents
    # Execution runtime for agents.
    #
    # AgentRuntime handles the ReAct (Reasoning and Acting) loop, code execution,
    # planning, and evaluation. It is created by Agent and receives delegated
    # +run()+ and +step()+ calls.
    #
    # == Separation of Concerns
    #
    # This separation keeps responsibilities clear:
    # - *Agent* owns configuration, tools, model, and prompt generation
    # - *AgentRuntime* owns execution state, ReAct loop, and step processing
    #
    # == Included Concerns
    #
    # The runtime includes several mixins that provide specific functionality:
    #
    # - *ReActLoop::Core* - Main execution loop and run entry points
    # - *ReActLoop::Control* - Fiber bidirectional control (user input, confirmations)
    # - *ReActLoop::Repetition* - Loop detection to prevent infinite loops
    # - *Evaluation* - Metacognition phase for self-assessment
    # - *StepExecution* - Individual step processing
    # - *Planning* - Periodic replanning during long runs
    # - *CodeExecution* - Code generation and sandbox execution
    #
    # == ReAct Loop
    #
    # The ReAct pattern alternates between:
    # 1. *Reasoning* - Model generates code based on task and observations
    # 2. *Acting* - Code executes in sandbox, producing observations
    # 3. *Repeat* - Until final_answer called or max_steps reached
    #
    # @see Agent For the public API
    # @see Concerns::ReActLoop For execution loop details
    # @see Concerns::Planning For planning behavior
    # @see Concerns::Evaluation For metacognition
    class AgentRuntime
      # Behavior concerns
      include Concerns::Monitorable
      include Concerns::ReActLoop
      include Concerns::ReActLoop::Control
      include Concerns::ReActLoop::Repetition
      include Concerns::Evaluation
      include Concerns::StepExecution
      include Concerns::Planning
      include Concerns::CodeExecution

      # Extracted modules
      include Accessors
      include Initialization
      include AgentRuntime::StepExecution

      # Creates a new runtime.
      #
      # @param model [Models::Model] The LLM model for code generation
      # @param tools [Hash{String => Tools::Tool}] Available tools (name => tool)
      # @param executor [Executors::Executor] Code executor for sandbox execution
      # @param memory [Runtime::AgentMemory] Agent memory for conversation history
      # @param max_steps [Integer] Maximum steps before stopping
      # @param logger [Logging::Logger] Logger instance for operation logging
      # @param custom_instructions [String, nil] Additional instructions
      # @param planning_interval [Integer, nil] Steps between replanning
      # @param planning_templates [Hash, nil] Custom planning prompt templates
      # @param spawn_config [Types::SpawnConfig, nil] Configuration for child agents
      # @param evaluation_enabled [Boolean] Enable metacognition (default: false)
      # @param authorized_imports [Array<String>] Allowed require paths
      # @return [AgentRuntime] A new runtime instance
      #
      # @see Agent#initialize Usually created via Agent, not directly
      def initialize(
        model:, tools:, executor:, memory:, max_steps:, logger:,
        custom_instructions: nil, planning_interval: nil, planning_templates: nil,
        spawn_config: nil, evaluation_enabled: false, authorized_imports: nil
      )
        assign_core(model:, tools:, executor:, memory:, max_steps:, logger:)
        assign_optional(custom_instructions:, spawn_config:, authorized_imports:)
        initialize_planning(planning_interval:, planning_templates:)
        initialize_evaluation(evaluation_enabled:)
        setup_consumer
      end
    end
  end
end
