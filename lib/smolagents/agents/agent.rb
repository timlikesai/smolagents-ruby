require_relative "agent/accessors"
require_relative "agent/initialization"
require_relative "agent/execution"
require_relative "agent/prompts"
require_relative "agent/delegation"

module Smolagents
  module Agents
    # An agent that writes Ruby code to accomplish tasks.
    #
    # Agents generate Ruby code that calls tools, performs computations,
    # uses loops/conditionals, and stores intermediate results. Code executes
    # in a sandboxed environment with configurable safety limits.
    #
    # Agent handles configuration and prompt generation. Execution is delegated
    # to AgentRuntime which manages the ReAct loop, planning, and step processing.
    #
    # == Architecture
    #
    # The Agent class follows a separation of concerns pattern:
    #
    # - *Agent* owns configuration, tools, model, and prompt generation
    # - *AgentRuntime* owns execution state, ReAct loop, and step processing
    # - *Executor* owns sandboxed code execution
    # - *AgentMemory* owns conversation history and context management
    #
    # == Execution Modes
    #
    # Agents support three execution modes:
    #
    # 1. *Synchronous* (+run+) - Returns final result, auto-approves control requests
    # 2. *Streaming* (+run(stream: true)+) - Returns Enumerator yielding steps
    # 3. *Fiber* (+run_fiber+) - Returns Fiber for bidirectional control
    #
    # @example Minimal agent with mock model (for testing)
    #   model = Smolagents::Testing::MockModel.new(responses: ["final_answer('4')"])
    #   agent = Smolagents::Agents::Agent.new(
    #     model: model,
    #     tools: [Smolagents::Tools::FinalAnswerTool.new]
    #   )
    #   result = agent.run("What is 2+2?")
    #   result.success?
    #   # => true
    #
    # @example With AgentBuilder DSL
    #   agent = Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .tools(:search, :web)
    #     .as(:researcher)
    #     .max_steps(15)
    #     .build
    #
    # @example Streaming execution
    #   agent.run("Search for Ruby 4.0", stream: true).each do |step|
    #     puts "Step #{step.step_number}: #{step.observations}"
    #   end
    #
    # @see AgentRuntime For execution logic and ReAct loop
    # @see Executors::LocalRuby Code execution sandbox
    # @see Runtime::AgentMemory Conversation history management
    # @see Types::RunResult The result type from agent runs
    class Agent
      include Events::Consumer
      include Concerns::Monitorable
      include Concerns::ManagedAgents
      include Concerns::AgentHealth::Health
      include Persistence::Serializable
      include Accessors
      include Initialization
      include Execution
      include Prompts
      include Delegation

      # Creates a new agent.
      #
      # Initializes the agent with a model, tools, and optional configuration.
      # The agent sets up its runtime, executor, and memory based on the provided
      # parameters and global configuration defaults.
      #
      # @param model [Models::Model] The LLM model for generating code
      # @param tools [Array<Tools::Tool>] Tools available to the agent
      # @param config [Types::AgentConfig, nil] Configuration object (uses defaults if nil)
      # @param executor [Executors::Executor, nil] Code executor (default: LocalRuby)
      # @param managed_agents [Hash{String => Agent}, nil] Sub-agents for delegation
      # @param logger [Logging::Logger, nil] Custom logger instance (default: NullLogger)
      #
      # @return [Agent] A new agent instance
      #
      # @example Creating an agent with minimal configuration
      #   model = Smolagents::Testing::MockModel.new(responses: ["final_answer('done')"])
      #   agent = Smolagents::Agents::Agent.new(
      #     model: model,
      #     tools: [Smolagents::Tools::FinalAnswerTool.new]
      #   )
      #
      # @see Types::AgentConfig For configuration options
      def initialize(model:, tools:, config: nil, executor: nil, managed_agents: nil, logger: nil)
        agent_config = config || Types::AgentConfig.default
        initialize_core(model:, executor:, logger:, agent_config:)
        initialize_tools(tools, managed_agents)
        initialize_memory_and_runtime(agent_config)
      end

      # Connects the agent to an event queue for observability.
      #
      # Events from the agent and its runtime will be published to the queue.
      # This enables monitoring, logging, and integration with external systems.
      #
      # @param queue [Events::Queue] The event queue to connect to
      # @return [self] The agent instance for chaining
      def connect_to(queue)
        super
        @runtime&.connect_to(queue)
        self
      end
    end

    # Factory method to create an agent.
    #
    # Convenience method equivalent to +Agent.new+.
    #
    # @param model [Models::Model] The LLM model
    # @param tools [Array<Tools::Tool>] Tools available (default: [])
    # @option options [Types::AgentConfig] :config Configuration object
    # @option options [Executors::Executor] :executor Code executor
    # @option options [Hash{String => Agent}] :managed_agents Sub-agents
    # @option options [Logging::Logger] :logger Custom logger
    #
    # @return [Agent] A new agent instance
    def self.create(model:, tools: [], **) = Agent.new(model:, tools:, **)

    # Creates a code agent (alias for create).
    #
    # @deprecated Use {.create} instead
    # @param model [Models::Model] The LLM model
    # @param tools [Array<Tools::Tool>] Tools available (default: [])
    # @option options [Types::AgentConfig] :config Configuration object
    # @option options [Executors::Executor] :executor Code executor
    # @return [Agent] A new agent instance
    def self.code(model:, tools: [], **) = Agent.new(model:, tools:, **)
  end
end
