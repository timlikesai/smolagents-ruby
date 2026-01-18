module Smolagents
  # Entry point DSL for creating agents, teams, models, and pipelines.
  #
  # Provides the fluent API methods that make Smolagents intuitive to use.
  # Extended into the Smolagents module to provide top-level access.
  #
  # @api private
  module DSL
    # ============================================================
    # Agent Entry Point
    # ============================================================

    # Creates a new agent builder.
    #
    # All agents write Ruby code. Build with composable atoms:
    # - `.model { }` - the LLM (required)
    # - `.tools(:search, :web)` - what the agent can use
    # - `.as(:researcher)` - behavioral instructions (persona)
    # - `.with(:researcher)` - specialization (tools + persona bundle)
    #
    # The agent automatically includes the final_answer tool.
    #
    # @return [Builders::AgentBuilder] New agent builder (fluent interface)
    #
    # @example Returns an AgentBuilder for fluent configuration
    #   builder = Smolagents.agent
    #   builder.class.name  #=> "Smolagents::Builders::AgentBuilder"
    #
    # @example Minimal agent
    #   agent = Smolagents.agent
    #     .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .build
    #   agent.class.name  #=> "Smolagents::Agents::Agent"
    #
    # @see Builders::AgentBuilder Configuration options
    def agent
      builder = Builders::AgentBuilder.create.tools(:final_answer)

      # Auto-attach interactive handlers in IRB/Pry sessions
      if Interactive.session?
        Interactive.default_handlers.each { |event, handler| builder = builder.on(event, &handler) }
      end

      builder
    end

    # Registers a custom specialization.
    #
    # Specializations bundle tools and persona instructions into named
    # configurations. All agents think in Ruby code.
    #
    # @param name [Symbol] Unique name for the specialization
    # @param tools [Array<Symbol>] Tool names to include
    # @param instructions [String, nil] Persona instructions
    # @return [Types::Specialization] The registered specialization
    #
    # @example Register a custom specialization
    #   Smolagents.specialization(:my_expert,
    #     tools: [:custom_tool, :another_tool],
    #     instructions: "You are an expert in X. Your approach: ..."
    #   )
    #
    # @see Specializations Built-in specializations
    def specialization(name, **)
      Specializations.register(name, **)
    end

    # ============================================================
    # Testing Entry Points
    # ============================================================

    # Entry point for model testing DSL.
    #
    # Creates a test builder for defining and running model tests.
    # Supports both real models and MockModel for unit testing.
    #
    # @param type [Symbol] Test type (:model is currently the only supported type)
    # @return [Builders::TestBuilder] A new test builder instance
    #
    # @example Create a test builder
    #   builder = Smolagents.test(:model)
    #   builder.class.name  #=> "Smolagents::Builders::TestBuilder"
    #
    # @see Builders::TestBuilder Full builder API
    def test(type = :model)
      case type
      when :model then Builders::TestBuilder.new
      else raise ArgumentError, "Unknown test type: #{type}"
      end
    end

    # Entry point for defining test suites.
    #
    # Creates a requirement builder for defining test suites with
    # capability requirements and reliability thresholds.
    #
    # @param name [Symbol, String] Name for the test suite
    # @return [Testing::RequirementBuilder] A new requirement builder
    #
    # @example Define requirements
    #   Smolagents.test_suite(:my_agent)
    #     .requires(:tool_use)
    #     .requires(:reasoning)
    #     .reliability(runs: 10, threshold: 0.95)
    #
    # @see Testing::RequirementBuilder Full builder API
    def test_suite(name)
      Testing::RequirementBuilder.new(name)
    end

    # ============================================================
    # Team and Coordination
    # ============================================================

    # Creates a new team builder for multi-agent composition.
    #
    # Teams coordinate multiple agents to solve complex tasks collaboratively.
    #
    # @return [Builders::TeamBuilder] New team builder (fluent interface)
    #
    # @example Create a team builder
    #   builder = Smolagents.team
    #   builder.class.name  #=> "Smolagents::Builders::TeamBuilder"
    #
    # @see Builders::TeamBuilder Configuration options
    def team
      Builders::TeamBuilder.create
    end

    # Creates a Ralph Loop for self-referential iteration.
    #
    # Ralph Loop runs an agent repeatedly, injecting context about previous
    # iterations so the agent can build on its own work rather than starting over.
    #
    # @param agent [Agent] The agent to run
    # @param prompt [String] The base task prompt
    # @param max_iterations [Integer] Maximum iterations (0 = unlimited)
    # @param completion_promise [String, nil] Condition for completion
    # @param work_dir [String] Directory to check for git state
    # @return [Orchestrators::LoopResult] Result with all iteration history
    #
    # @see Orchestrators::RalphLoop For more control
    def ralph_loop(agent:, prompt:, max_iterations: 10, completion_promise: nil, work_dir: Dir.pwd)
      Orchestrators::RalphLoop.new(
        agent:, prompt:, max_iterations:, completion_promise:, work_dir:
      ).run
    end

    # ============================================================
    # Model Configuration
    # ============================================================

    # Creates a new model builder.
    #
    # Models handle communication with LLMs. Smolagents supports:
    # - OpenAI (gpt-4, gpt-3.5-turbo, etc.)
    # - Anthropic (Claude models)
    # - LiteLLM (multi-provider)
    # - Local models (via LM Studio, Ollama, etc.)
    #
    # @param type_or_model [Symbol, Model] Model type or existing model instance
    # @return [Builders::ModelBuilder] New model builder (fluent interface)
    #
    # @example OpenAI model
    #   Smolagents.model(:openai).id("gpt-4").api_key("sk-...").build
    #
    # @see Builders::ModelBuilder Configuration options
    def model(type_or_model = :openai)
      Builders::ModelBuilder.create(type_or_model)
    end

    # ============================================================
    # Pipeline and Tool Execution
    # ============================================================

    # Creates a new empty pipeline.
    #
    # Pipelines compose tool calls into reusable execution chains.
    #
    # @return [Pipeline] New empty pipeline
    #
    # @example Create a pipeline
    #   pipeline = Smolagents.pipeline
    #   pipeline.class.name  #=> "Smolagents::Pipeline"
    #
    # @see Pipeline Full API documentation
    def pipeline
      Pipeline.new
    end

    # Executes a tool and returns a chainable pipeline.
    #
    # Convenience method for starting a pipeline with a single tool call.
    #
    # @param tool_name [Symbol, String] Name of the tool to execute
    # @param args [Hash] Arguments to pass to the tool
    # @return [Pipeline] Pipeline with the tool call added
    #
    # @example Start a pipeline with a tool call
    #   pipeline = Smolagents.run(:final_answer, answer: "test")
    #   pipeline.class.name  #=> "Smolagents::Pipeline"
    #
    # @see #pipeline For creating empty pipelines
    def run(tool_name, **args)
      Pipeline.new.call(tool_name, **args)
    end

    # ============================================================
    # Interactive Session Support
    # ============================================================

    # Shows contextual help for using smolagents.
    #
    # @param topic [Symbol, String, nil] Specific help topic
    # @return [void]
    #
    # @example General help
    #   Smolagents.help
    #
    # @example Model configuration help
    #   Smolagents.help :models
    def help(topic = nil)
      Interactive.help(topic)
    end

    # Lists available models from local servers and cloud providers.
    #
    # @param refresh [Boolean] Force a fresh scan
    # @param all [Boolean] Show all models including unloaded
    # @param filter [Symbol, nil] Filter by status
    # @return [Array<Discovery::DiscoveredModel>] Discovered models
    #
    # @example List ready models
    #   Smolagents.models
    #
    # @example List all models including unloaded
    #   Smolagents.models(all: true)
    def models(refresh: false, all: false, filter: nil)
      Interactive.models(refresh:, all:, filter:)
    end

    # Performs a discovery scan for available models and providers.
    #
    # @param timeout [Float] HTTP timeout in seconds
    # @param custom_endpoints [Array<Hash>] Additional endpoints to scan
    # @return [Discovery::Result] Discovery results
    #
    # @example Basic scan
    #   result = Smolagents.discover
    #   puts result.summary
    def discover(timeout: 2.0, custom_endpoints: [])
      Discovery.scan(timeout:, custom_endpoints:)
    end

    # ============================================================
    # Event Discovery
    # ============================================================

    # Returns all registered event names.
    #
    # Use for runtime discovery of available events.
    #
    # @return [Array<Symbol>] All event names
    #
    # @example List all events
    #   Smolagents.events.include?(:step_complete)  #=> true
    def events
      Events::Registry.all
    end

    # Returns a specific event definition.
    #
    # @param name [Symbol] Event name
    # @return [Events::Registry::EventDefinition, nil]
    #
    # @example Get event info
    #   defn = Smolagents.event(:step_complete)
    #   defn.signature  #=> "on(:step_complete) { |step, context| ... }"
    def event(name)
      Events::Registry[name]
    end

    # Returns markdown documentation for all events.
    #
    # @return [String] Formatted documentation
    #
    # @example Generate docs
    #   puts Smolagents.event_docs
    def event_docs
      Events::Registry.documentation
    end

    # ============================================================
    # Concern Discovery
    # ============================================================

    # Returns all registered concern names.
    #
    # Use for runtime discovery of available concerns.
    #
    # @return [Array<Symbol>] All concern names
    #
    # @example List all concerns
    #   Smolagents.concerns.include?(:react_loop)  #=> true
    def concerns
      Concerns::Registry.all
    end

    # Returns a specific concern info.
    #
    # @param name [Symbol] Concern name
    # @return [Concerns::Registry::ConcernInfo, nil]
    #
    # @example Get concern info
    #   info = Smolagents.concern(:react_loop)
    #   info.nil?  #=> false
    def concern(name)
      Concerns::Registry[name]
    end

    # Returns markdown documentation for all concerns.
    #
    # @return [String] Formatted documentation
    #
    # @example Generate docs
    #   puts Smolagents.concern_docs
    def concern_docs
      Concerns::Registry.documentation
    end

    # Returns the concern dependency graph.
    #
    # Each concern maps to a hash with :depends_on and :depended_by keys.
    #
    # @return [Hash{Symbol => Hash}] Dependency graph
    #
    # @example Visualize dependencies
    #   graph = Smolagents.concern_graph
    #   graph[:resilience]  #=> { depends_on: [:circuit_breaker, :rate_limiter], depended_by: [] }
    def concern_graph
      Concerns::Registry.graph
    end

    # Returns concerns grouped by category.
    #
    # @return [Hash{Symbol => Array<Concerns::Registry::ConcernInfo>}] Concerns by category
    #
    # @example List concerns by category
    #   Smolagents.concerns_by_category.is_a?(Hash)  #=> true
    def concerns_by_category
      Concerns::Registry.by_category
    end
  end
end
