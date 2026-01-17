require_relative "agents/react_loop"
require_relative "agents/planning"
require_relative "agents/managed"
require_relative "agents/async"
require_relative "agents/early_yield"
require_relative "agents/specialized"
require_relative "agents/self_refine"
require_relative "agents/reflection_memory"
require_relative "agents/mixed_refinement"

module Smolagents
  module Concerns
    # Agent behavior concerns for building intelligent agents.
    #
    # This module namespace organizes concerns for agent behavior.
    # Each concern can be included independently or composed together.
    #
    # == Concern Composition Matrix
    #
    # The following documents which concerns can be combined and their dependencies:
    #
    # === ReActLoop (Base Loop)
    # - *Requires*: None
    # - *Auto-includes*: Core, Execution
    # - *Notes*: Base loop, includes Events
    #
    # === ReActLoop::Core
    # - *Requires*: None
    # - *Notes*: Setup and run entry points
    #
    # === ReActLoop::Execution
    # - *Requires*: None
    # - *Auto-includes*: Completion, ErrorHandling
    # - *Notes*: Main loop, step monitoring
    #
    # === ReActLoop::Control
    # - *Requires*: ReActLoop
    # - *Notes*: Fiber bidirectional control
    #
    # === ReActLoop::Repetition
    # - *Requires*: ReActLoop
    # - *Notes*: Loop detection, stuck agents
    #
    # === Evaluation
    # - *Requires*: ReActLoop
    # - *Notes*: Metacognition phase
    #
    # === Planning
    # - *Requires*: ReActLoop
    # - *Notes*: Pre-Act planning
    #
    # === CodeExecution
    # - *Requires*: None
    # - *Auto-includes*: CodeGeneration, CodeParsing, ExecutionContext
    # - *Notes*: Can use standalone
    #
    # === StepExecution
    # - *Requires*: None
    # - *Notes*: Step timing wrapper
    #
    # === Monitorable
    # - *Requires*: None
    # - *Auto-includes*: Events::Emitter
    # - *Notes*: Can use standalone
    #
    # === ManagedAgents
    # - *Requires*: None
    # - *Notes*: Sub-agent delegation
    #
    # === AsyncTools
    # - *Requires*: None
    # - *Notes*: Parallel tool execution
    #
    # === EarlyYield
    # - *Requires*: None
    # - *Notes*: Speculative execution
    #
    # === Specialized
    # - *Requires*: None
    # - *Notes*: DSL for agent definition
    #
    # === SelfRefine
    # - *Requires*: None
    # - *Auto-includes*: Loop, Feedback, Prompts
    # - *Notes*: Iterative improvement
    #
    # === ReflectionMemory
    # - *Requires*: None
    # - *Auto-includes*: Store, Injection, Analysis
    # - *Notes*: Cross-run learning
    #
    # === MixedRefinement
    # - *Requires*: None
    # - *Notes*: Cross-model refinement
    #
    # == Dependency Details
    #
    # === ReActLoop (Base Loop)
    # - *Auto-includes*: ReActLoop::Core, ReActLoop::Execution
    # - *Provides*: run(), run_fiber(), setup_agent(config), step monitoring
    # - *Requires*: Classes must implement step(task, step_number:)
    # - *Instance vars*: @tools, @model, @memory, @max_steps, @logger, @state
    # - *Note*: setup_agent() takes Types::SetupConfig object
    #
    # === ReActLoop::Control (Bidirectional Control)
    # - *Requires*: Must be included AFTER ReActLoop
    # - *Provides*: request_input(), request_confirmation(), escalate_query()
    # - *Events*: ControlYielded, ControlResumed
    # - *Note*: Only works in Fiber context (run_fiber, not run)
    #
    # === ReActLoop::Repetition (Loop Detection)
    # - *Requires*: Must be included AFTER ReActLoop
    # - *Provides*: check_repetition(), RepetitionResult, RepetitionConfig
    # - *Events*: RepetitionDetected
    # - *Overrides*: check_and_handle_repetition() stub in Execution
    #
    # === Evaluation (Metacognition)
    # - *Requires*: Must be included AFTER ReActLoop
    # - *Provides*: evaluate_progress(), execute_evaluation_if_needed()
    # - *Events*: EvaluationCompleted
    # - *Overrides*: execute_evaluation_if_needed() stub in Execution
    #
    # === Planning (Pre-Act Planning)
    # - *Requires*: Must be included AFTER ReActLoop for proper method resolution
    # - *Provides*: initialize_planning(), execute_planning_step_if_needed()
    # - *Overrides*: execute_planning_step_if_needed(), execute_initial_planning_if_needed()
    # - *Instance vars*: @planning_interval, @planning_templates, @plan_context
    #
    # === CodeExecution (Ruby Execution Pipeline)
    # - *Can use standalone*: Does not require ReActLoop
    # - *Auto-includes*: CodeGeneration, CodeParsing, ExecutionContext
    # - *Provides*: execute_step(), execute_code_action()
    # - *Requires*: @model, @executor, @max_steps
    #
    # === Monitorable (Step Monitoring)
    # - *Can use standalone*: Does not require ReActLoop
    # - *Auto-includes*: Events::Emitter
    # - *Provides*: monitor_step(), track_tokens(), step_monitors
    #
    # === StepExecution (Step Timing)
    # - *Can use standalone*: Does not require ReActLoop
    # - *Provides*: with_step_timing()
    # - *Requires*: @logger for error logging
    #
    # == Model-Level Concerns
    #
    # These concerns apply to Model classes, not agents:
    #
    #   | Concern          | Auto-Includes                                    | Purpose                   |
    #   |------------------|--------------------------------------------------|---------------------------|
    #   | ModelReliability | ModelFallback, HealthRouting, RetryExecution,    | Retry, failover, routing  |
    #   |                  | ReliabilityNotifications, Events::Emitter/Consumer |                           |
    #   | ModelHealth      | Checks, Discovery                                | Health checks, discovery  |
    #
    # == Recommended Compositions
    #
    # === Full-Featured Agent (AgentRuntime)
    #   include Concerns::Monitorable           # Step monitoring
    #   include Concerns::ReActLoop             # Base loop (includes Core, Execution)
    #   include Concerns::ReActLoop::Control    # Fiber bidirectional control
    #   include Concerns::ReActLoop::Repetition # Loop detection
    #   include Concerns::Evaluation            # Metacognition phase
    #   include Concerns::StepExecution         # Step timing
    #   include Concerns::Planning              # Pre-Act planning
    #   include Concerns::CodeExecution         # Code generation
    #
    # === Minimal Code Agent
    #   include Concerns::ReActLoop             # Base loop
    #   include Concerns::CodeExecution         # Code generation
    #
    # === Agent with Refinement
    #   include Concerns::ReActLoop             # Base loop
    #   include Concerns::CodeExecution         # Code generation
    #   include Concerns::SelfRefine            # Self-refinement
    #
    # === Agent with Memory
    #   include Concerns::ReActLoop             # Base loop
    #   include Concerns::CodeExecution         # Code generation
    #   include Concerns::ReflectionMemory      # Cross-run learning
    #
    # @example Building a minimal code agent
    #   class MyAgent
    #     include Concerns::ReActLoop
    #     include Concerns::CodeExecution
    #
    #     def initialize(model:, tools:)
    #       config = Types::SetupConfig.create(model:, tools:, max_steps: 10)
    #       setup_agent(config)
    #       setup_code_execution
    #       finalize_code_execution
    #     end
    #
    #     def step(task, step_number:)
    #       # ...
    #     end
    #   end
    #
    # @example Building a planning agent with control
    #   class InteractiveAgent
    #     include Concerns::ReActLoop
    #     include Concerns::ReActLoop::Control
    #     include Concerns::Planning
    #     include Concerns::CodeExecution
    #
    #     def initialize(model:, tools:)
    #       @model = model
    #       config = Types::SetupConfig.create(model:, tools:, max_steps: 10, planning_interval: 3)
    #       setup_agent(config)
    #       setup_code_execution
    #     end
    #
    #     def step(task, step_number:)
    #       # Can call request_input() or request_confirmation() here
    #     end
    #   end
    #
    # @see ReActLoop For the main agent execution loop
    # @see ReActLoop::Control For Fiber-based bidirectional control
    # @see ReActLoop::Repetition For loop detection
    # @see Evaluation For metacognition after steps
    # @see Planning For agent planning and replanning
    # @see CodeExecution For code generation and execution
    # @see ManagedAgents For sub-agent management
    # @see Specialized For agent DSL definitions
    # @see SelfRefine For iterative refinement
    # @see ReflectionMemory For cross-run learning
    # @see MixedRefinement For cross-model refinement
    # @see ModelReliability For model retry and failover
    # @see ModelHealth For model health checking
    module Agents
    end
  end
end
