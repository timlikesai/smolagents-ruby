require_relative "smolagents/version"
require_relative "smolagents/errors"
require_relative "smolagents/logging"
require_relative "smolagents/security"
require_relative "smolagents/telemetry"
require_relative "smolagents/utilities"
require_relative "smolagents/http"
require_relative "smolagents/events"
require_relative "smolagents/concerns"
require_relative "smolagents/types"
require_relative "smolagents/config"
require_relative "smolagents/executors"
require_relative "smolagents/models"
require_relative "smolagents/tools"
require_relative "smolagents/pipeline"
require_relative "smolagents/persistence"
require_relative "smolagents/orchestrators"
require_relative "smolagents/agents"
require_relative "smolagents/builders"
require_relative "smolagents/toolkits"
require_relative "smolagents/personas"
require_relative "smolagents/specializations"
require_relative "smolagents/discovery"
require_relative "smolagents/interactive"

# Smolagents: Delightfully simple agents that think in Ruby.
#
# Smolagents provides a complete framework for building AI agents in Ruby.
# Not a Python port -- a Ruby-first design using `Data.define`, pattern matching,
# and fluent APIs. The interface is designed to be intuitive and idiomatic.
#
# == Core Components
#
# - **Agents**: CodeAgent (writes Ruby code), ToolAgent (JSON tool calls)
# - **Models**: OpenAI, Anthropic, LiteLLM, and local model support
# - **Tools**: Built-in tools for search, web visits, and custom tool creation
# - **Toolkits**: Tool groupings (:search, :web, :data, :research)
# - **Personas**: Behavioral instruction templates
# - **Builders**: Fluent API for agent and team configuration
# - **Pipeline**: Composable tool execution chains
# - **Orchestrators**: Multi-agent coordination and sub-agent management
# - **Executors**: Sandboxed Ruby code execution (Ruby, Docker, Ractor)
# - **Telemetry**: Event-driven observability and tracing
# - **Persistence**: Agent state serialization and loading
#
# == Quick Start
#
# @example Minimal agent (returns AgentBuilder)
#   builder = Smolagents.agent
#   builder.class.name.include?("Builder")  #=> true
#
# @example Check available toolkits
#   Smolagents::Toolkits.names  #=> [:search, :web, :data, :research]
#
# @example Check available personas
#   Smolagents::Personas.names  #=> [:researcher, :fact_checker, :analyst, :calculator, :scraper]
#
# @example Check available specializations
#   Smolagents::Specializations.names.include?(:researcher)  #=> true
#
# == Builder Method Distinctions
#
# Agents are configured with three key methods. Understanding the distinction
# is essential for effective agent composition:
#
# [+.tools(:name)+]
#   Adds a toolkit (auto-expands to individual tools) or individual tools.
#   *What the agent can use.* Toolkits are named groups of related tools.
#
# [+.as(:name)+]
#   Applies a persona (behavioral instructions only).
#   *How the agent should behave.* Does not add any tools.
#
# [+.with(:name)+]
#   Adds a specialization (convenience bundle: toolkit + persona together).
#   *Shorthand for .tools + .as combined.*
#
# The relationship:
#   .tools(:search).as(:researcher)  ==  .with(:researcher)
#
# Use +.tools+ and +.as+ for fine-grained control. Use +.with+ for convenience.
#
# @example Using .tools (add tools only)
#   agent = Smolagents.agent
#     .tools(:search, :web)         # Adds search + web tools
#     .model { my_model }
#     .build
#
# @example Using .as (add persona only)
#   agent = Smolagents.agent
#     .tools(:search)               # Must add tools separately
#     .as(:researcher)              # Adds behavioral instructions
#     .model { my_model }
#     .build
#
# @example Using .with (convenience: tools + persona)
#   agent = Smolagents.agent
#     .with(:researcher)            # Same as .tools(:research).as(:researcher)
#     .model { my_model }
#     .build
#
# @example Combining methods for customization
#   agent = Smolagents.agent
#     .with(:researcher)            # Start with researcher bundle
#     .tools(:data)                 # Add extra data tools
#     .instructions("Be concise")   # Add custom instructions
#     .model { my_model }
#     .build
#
# == Type System
#
# Smolagents uses Ruby 4.0's `Data.define` pattern for immutable data types.
# Key types are re-exported at the module level for convenience:
#
# @example Working with types
#   Smolagents::TokenUsage.ancestors.include?(Data)  #=> true
#   Smolagents::ToolCall.ancestors.include?(Data)  #=> true
#   Smolagents::RunResult.ancestors.include?(Data)  #=> true
#
# @see Toolkits Available toolkits (:search, :web, :data, :research)
# @see Personas Available personas (:researcher, :fact_checker, :analyst, :calculator, :scraper)
# @see Specializations Available specializations (:researcher, :fact_checker, :data_analyst, :calculator, :web_scraper)
# @see Builders::AgentBuilder Full builder API
# @see Models Model adapters for different LLM providers
# @see Tools::Tool Base class for creating custom tools
#
module Smolagents
  class << self
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
    # @example Builder responds to configuration methods
    #   builder = Smolagents.agent
    #   builder.respond_to?(:tools)  #=> true
    #   builder.respond_to?(:model)  #=> true
    #   builder.respond_to?(:as)  #=> true
    #   builder.respond_to?(:with)  #=> true
    #   builder.respond_to?(:build)  #=> true
    #
    # @example Minimal agent
    #   agent = Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .build
    #
    # @example With tools
    #   agent = Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .tools(:search, :web)
    #     .build
    #
    # @example With persona
    #   agent = Smolagents.agent
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .tools(:search)
    #     .as(:researcher)
    #     .build
    #
    # @example Using specialization (tools + persona)
    #   agent = Smolagents.agent
    #     .with(:researcher)
    #     .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
    #     .build
    #
    # @see Builders::AgentBuilder Configuration options
    # @see Agents::Agent Implementation details
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
    # Specializations are composable capability bundles (tools + instructions)
    # that can be mixed into agents via `.with()`.
    #
    # @param name [Symbol] Unique name for the specialization
    # @param tools [Array<Symbol>] Tool names to include
    # @param instructions [String, nil] Instructions to add to system prompt
    # @param requires [Symbol, nil] Capability requirement (:code for code execution)
    # @return [Types::Specialization] The registered specialization
    #
    # @example Built-in specializations are available
    #   Smolagents::Specializations.names.include?(:researcher)  #=> true
    #   Smolagents::Specializations.names.include?(:calculator)  #=> true
    #
    # @example Register a custom specialization
    #   Smolagents.specialization(:my_expert,
    #     tools: [:custom_tool, :another_tool],
    #     instructions: "You are an expert in X. Your approach: ..."
    #   )
    #
    #   agent = Smolagents.agent
    #     .with(:my_expert)
    #     .model { my_model }
    #     .build
    #
    # @example Specialization that requires code execution
    #   Smolagents.specialization(:code_reviewer,
    #     tools: [:ruby_interpreter],
    #     instructions: "You review and analyze Ruby code...",
    #     requires: :code
    #   )
    #
    # @see Specializations Built-in specializations
    # @see Builders::AgentBuilder#with Using specializations
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
    # @example Basic test
    #   Smolagents.test(:model)
    #     .task("What is 2+2?")
    #     .expects { |out| out.include?("4") }
    #     .run(model)
    #
    # @example With MockModel
    #   Smolagents.test(:model)
    #     .task("Calculate 5 * 5")
    #     .expects { |out| out.include?("25") }
    #     .with_mock do |mock|
    #       mock.queue_final_answer("25")
    #     end
    #
    # @see Builders::TestBuilder Full builder API
    # @see Testing::MockModel Mock model for testing
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
    # @see Testing::Capabilities Available capabilities
    def test_suite(name)
      Testing::RequirementBuilder.new(name)
    end

    # ============================================================
    # Team and Coordination
    # ============================================================

    # Creates a new team builder for multi-agent composition.
    #
    # Teams coordinate multiple agents to solve complex tasks collaboratively.
    # Use them for:
    # - Dividing work across specialized agents
    # - Orchestrating sequential workflows
    # - Managing communication between agents
    #
    # @return [Builders::TeamBuilder] New team builder (fluent interface)
    #
    # @example Returns a TeamBuilder for fluent configuration
    #   builder = Smolagents.team
    #   builder.class.name  #=> "Smolagents::Builders::TeamBuilder"
    #
    # @example TeamBuilder responds to configuration methods
    #   builder = Smolagents.team
    #   builder.respond_to?(:model)  #=> true
    #   builder.respond_to?(:agent)  #=> true
    #   builder.respond_to?(:build)  #=> true
    #
    # @example Creating a research and writing team
    #   Smolagents.team
    #     .model { OpenAI.gpt4 }
    #     .agent(researcher, as: "researcher")
    #     .agent(writer, as: "writer")
    #     .coordinate("Research the topic, then write a summary")
    #     .build
    #
    # @see Builders::TeamBuilder Configuration options
    # @see Orchestrators Multi-agent orchestration
    def team
      Builders::TeamBuilder.create
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
    # @param type_or_model [Symbol, Model] Model type (:openai, :anthropic, :litellm) or existing model instance
    # @return [Builders::ModelBuilder] New model builder (fluent interface)
    #
    # @example Returns a ModelBuilder for fluent configuration
    #   builder = Smolagents.model
    #   builder.class.name  #=> "Smolagents::Builders::ModelBuilder"
    #
    # @example ModelBuilder responds to configuration methods
    #   builder = Smolagents.model(:openai)
    #   builder.respond_to?(:id)  #=> true
    #   builder.respond_to?(:api_key)  #=> true
    #   builder.respond_to?(:build)  #=> true
    #
    # @example OpenAI model
    #   Smolagents.model(:openai).id("gpt-4").api_key("sk-...").build
    #
    # @example Local model via LiteLLM
    #   Smolagents.model(:litellm).id("openrouter/meta-llama/llama-3-8b").build
    #
    # @see Builders::ModelBuilder Configuration options
    # @see Models Available model types
    def model(type_or_model = :openai)
      Builders::ModelBuilder.create(type_or_model)
    end

    # ============================================================
    # Pipeline and Tool Execution
    # ============================================================

    # Creates a new empty pipeline.
    #
    # Pipelines compose tool calls into reusable execution chains.
    # They're ideal for:
    # - Multi-step workflows
    # - Data transformation chains
    # - Converting into reusable tools
    #
    # @return [Pipeline] New empty pipeline
    #
    # @example Returns a Pipeline instance
    #   pipeline = Smolagents.pipeline
    #   pipeline.class.name  #=> "Smolagents::Pipeline"
    #
    # @example Pipeline responds to composition methods
    #   pipeline = Smolagents.pipeline
    #   pipeline.respond_to?(:call)  #=> true
    #   pipeline.respond_to?(:then)  #=> true
    #   pipeline.respond_to?(:run)  #=> true
    #
    # @example Basic pipeline
    #   Smolagents.pipeline
    #     .call(:search, query: :input)
    #     .then(:visit) { |r| { url: r.first[:url] } }
    #     .run(query: "Ruby")
    #
    # @example Converting to a tool
    #   research = Smolagents.pipeline
    #     .call(:search, query: :input)
    #     .take(3)
    #
    #   tool = research.as_tool("quick_search", "Search and return top 3 results")
    #   agent = Smolagents.agent.model { ... }.tools(tool).build
    #
    # @see Pipeline Full API documentation
    def pipeline
      Pipeline.new
    end

    # Executes a tool and returns a chainable pipeline.
    #
    # Convenience method for starting a pipeline with a single tool call.
    # The result is a Pipeline that can be extended with additional steps.
    #
    # @param tool_name [Symbol, String] Name of the tool to execute
    # @param args [Hash] Arguments to pass to the tool
    # @return [Pipeline] Pipeline with the tool call added (fluent interface)
    #
    # @example Returns a Pipeline for chaining
    #   result = Smolagents.run(:final_answer, answer: "test")
    #   result.class.name  #=> "Smolagents::Pipeline"
    #
    # @example Chaining operations
    #   Smolagents.run(:search, query: "Ruby")
    #     .then(:visit) { |r| { url: r.first[:url] } }
    #     .pluck(:content)
    #     .run
    #
    # @example Equivalent to
    #   Smolagents.pipeline
    #     .call(:search, query: "Ruby")
    #     .then(:visit) { |r| { url: r.first[:url] } }
    #     .pluck(:content)
    #     .run
    #
    # @see #pipeline For creating empty pipelines
    # @see Pipeline Full API documentation
    def run(tool_name, **args)
      Pipeline.new.call(tool_name, **args)
    end

    # ============================================================
    # Interactive Session Support
    # ============================================================

    # Shows contextual help for using smolagents.
    #
    # In interactive sessions, displays help about models, tools, agents,
    # and discovery. Useful for getting started quickly.
    #
    # @param topic [Symbol, String, nil] Specific help topic (:models, :tools, :agents, :discovery)
    # @return [void]
    #
    # @example Help method is available
    #   Smolagents.respond_to?(:help)  #=> true
    #
    # @example General help
    #   Smolagents.help
    #
    # @example Model configuration help
    #   Smolagents.help :models
    #
    # @see Interactive#help Full help system
    def help(topic = nil)
      Interactive.help(topic)
    end

    # Lists available models from local servers and cloud providers.
    #
    # Scans localhost for inference servers (LM Studio, Ollama, llama.cpp, vLLM)
    # and checks environment variables for cloud API keys. Also scans any
    # servers configured via SMOLAGENTS_SERVERS environment variable.
    #
    # @param refresh [Boolean] Force a fresh scan instead of using cached results
    # @param all [Boolean] Show all models including unloaded (default: false)
    # @param filter [Symbol, nil] Filter by status (:ready, :loaded, :unloaded, :all)
    # @return [Array<Discovery::DiscoveredModel>] Discovered models
    #
    # @example Models method is available
    #   Smolagents.respond_to?(:models)  #=> true
    #
    # @example List ready models (default)
    #   Smolagents.models
    #
    # @example List all models including unloaded
    #   Smolagents.models(all: true)
    #
    # @example List only unloaded models
    #   Smolagents.models(filter: :unloaded)
    #
    # @example Force refresh
    #   Smolagents.models(refresh: true)
    #
    # @see Discovery#scan Full discovery API
    # @see Interactive#models Model listing with formatting
    def models(refresh: false, all: false, filter: nil)
      Interactive.models(refresh:, all:, filter:)
    end

    # Performs a discovery scan for available models and providers.
    #
    # Returns a detailed result with local servers, cloud providers,
    # and code examples for getting started.
    #
    # @param timeout [Float] HTTP timeout in seconds (default: 2.0)
    # @param custom_endpoints [Array<Hash>] Additional endpoints to scan
    # @return [Discovery::Result] Discovery results
    #
    # @example Discover method is available
    #   Smolagents.respond_to?(:discover)  #=> true
    #
    # @example Basic scan
    #   result = Smolagents.discover
    #   puts result.summary
    #   # => "4 local models, 2 cloud providers"
    #
    # @example With custom endpoint
    #   result = Smolagents.discover(
    #     custom_endpoints: [
    #       { provider: :llama_cpp, host: "gpu-server.local", port: 8080 }
    #     ]
    #   )
    #
    # @see Discovery#scan Full scan options
    def discover(timeout: 2.0, custom_endpoints: [])
      Discovery.scan(timeout:, custom_endpoints:)
    end
  end

  # ============================================================
  # Type System Re-exports
  # ============================================================

  # @!group Data Types

  # Token usage tracking for API calls.
  #
  # Records input and output token counts for cost tracking and
  # performance analysis.
  #
  # @see Types::TokenUsage
  TokenUsage = Types::TokenUsage

  # Timing information for agent execution.
  #
  # Tracks start time, end time, and duration of operations for
  # performance monitoring.
  #
  # @see Types::Timing
  Timing = Types::Timing

  # Runtime context for agent execution.
  #
  # Contains execution metadata like model info, tool names, and
  # environment configuration.
  #
  # @see Types::RunContext
  RunContext = Types::RunContext

  # Structured tool call representation.
  #
  # Contains tool name, arguments, and unique ID for tracking
  # tool invocations during agent execution.
  #
  # @see Types::ToolCall
  ToolCall = Types::ToolCall

  # Tool output with metadata.
  #
  # Wraps tool results with error status and original call for
  # full step traceability.
  #
  # @see Types::ToolOutput
  ToolOutput = Types::ToolOutput

  # Result of a complete agent run.
  #
  # Contains the final answer, all execution steps, token usage,
  # timing, and other metadata for the entire agent task.
  #
  # @see Types::RunResult
  RunResult = Types::RunResult

  # @!endgroup

  # ============================================================
  # Chat Message Types
  # ============================================================

  # @!group Messages

  # A message in agent conversation history.
  #
  # Represents a single message with role (user, assistant, system)
  # and content (text or multi-modal with images/audio).
  #
  # @see Types::ChatMessage
  ChatMessage = Types::ChatMessage

  # MIME types for images supported by agents.
  #
  # Hash of file format to MIME type. Supported formats:
  # png, jpg, jpeg, gif, webp, bmp, tiff, svg, ico.
  #
  # @see Types::IMAGE_MIME_TYPES
  IMAGE_MIME_TYPES = Types::IMAGE_MIME_TYPES

  # @!endgroup

  # ============================================================
  # Execution Steps
  # ============================================================

  # @!group Steps

  # A step where the agent decides on actions.
  #
  # Contains planned tool calls to be executed as part of the
  # agent's problem-solving process.
  #
  # @see Types::ActionStep
  ActionStep = Types::ActionStep

  # Builder for ActionStep instances.
  #
  # Mutable collection for constructing action steps during
  # agent execution. Use in agent implementations.
  #
  # @see Runtime::ActionStepBuilder
  ActionStepBuilder = Runtime::ActionStepBuilder

  # A step where the agent states the task/goal.
  #
  # Initial step containing the user's task description
  # and any context for solving it.
  #
  # @see Types::TaskStep
  TaskStep = Types::TaskStep

  # A step where the agent creates a solution plan.
  #
  # Contains the agent's reasoning about how to approach
  # the task and what steps to take.
  #
  # @see Types::PlanningStep
  PlanningStep = Types::PlanningStep

  # A step containing the system prompt used by the agent.
  #
  # Represents the instructions given to the LLM at the
  # beginning of execution.
  #
  # @see Types::SystemPromptStep
  SystemPromptStep = Types::SystemPromptStep

  # A step where the agent provides the final answer.
  #
  # Terminal step containing the agent's output to return
  # to the user. This ends agent execution.
  #
  # @see Types::FinalAnswerStep
  FinalAnswerStep = Types::FinalAnswerStep

  # Null Object for step parsing failures.
  #
  # Provides a safe default when parsing returns nil or empty.
  # Implements the full step interface with safe defaults, enabling
  # code to handle it uniformly without nil checks.
  #
  # @see Types::NullStep
  NullStep = Types::NullStep

  # @!endgroup

  # ============================================================
  # Multi-Modal Agent Types
  # ============================================================

  # @!group Multi-Modal Types

  # Base class for agent-compatible data types.
  #
  # Wraps values (text, images, audio) to provide consistent
  # serialization across different modalities. Enables agents to
  # handle text, images, and audio in a unified way.
  #
  # Subclasses: AgentText, AgentImage, AgentAudio
  #
  # @see Types::AgentType
  AgentType = Types::AgentType

  # Text content wrapper for agent I/O.
  #
  # Represents text data with string serialization and
  # embedding support for semantic operations.
  #
  # @see Types::AgentText
  AgentText = Types::AgentText

  # Image content wrapper for agent I/O.
  #
  # Represents image files (png, jpg, gif, etc.) with
  # automatic format detection and base64 encoding.
  #
  # Supported formats: png, jpg, jpeg, gif, webp, bmp, tiff, svg, ico
  #
  # @see Types::AgentImage
  AgentImage = Types::AgentImage

  # Audio content wrapper for agent I/O.
  #
  # Represents audio files (mp3, wav, ogg, etc.) with
  # automatic format detection and streaming support.
  #
  # Supported formats: mp3, wav, ogg, flac, m4a, aac, wma, aiff
  #
  # @see Types::AgentAudio
  AgentAudio = Types::AgentAudio

  # File formats supported for agent image inputs/outputs.
  #
  # Set containing: png, jpg, jpeg, gif, webp, bmp, tiff, svg, ico
  #
  # Use for validation before creating AgentImage instances.
  #
  # @example
  #   if ALLOWED_IMAGE_FORMATS.include?(format)
  #     image = AgentImage.new(path)
  #   end
  #
  # @see Types::ALLOWED_IMAGE_FORMATS
  ALLOWED_IMAGE_FORMATS = Types::ALLOWED_IMAGE_FORMATS

  # File formats supported for agent audio inputs/outputs.
  #
  # Set containing: mp3, wav, ogg, flac, m4a, aac, wma, aiff
  #
  # Use for validation before creating AgentAudio instances.
  #
  # @example
  #   if ALLOWED_AUDIO_FORMATS.include?(format)
  #     audio = AgentAudio.new(path)
  #   end
  #
  # @see Types::ALLOWED_AUDIO_FORMATS
  ALLOWED_AUDIO_FORMATS = Types::ALLOWED_AUDIO_FORMATS

  # Mapping from output type names to AgentType classes.
  #
  # Maps type strings to their corresponding classes for
  # dynamic type wrapping. Used internally by tool execution.
  #
  # Mapping:
  # - "string" => AgentText
  # - "text" => AgentText
  # - "image" => AgentImage
  # - "audio" => AgentAudio
  #
  # @example Dynamic wrapping by type name
  #   AgentType = AGENT_TYPE_MAPPING["image"]
  #   wrapped = AgentType.new(image_data)
  #
  # @see Types::AGENT_TYPE_MAPPING
  AGENT_TYPE_MAPPING = Types::AGENT_TYPE_MAPPING

  # @!endgroup

  # ============================================================
  # Plan and Context Types
  # ============================================================

  # @!group Planning

  # Planning context for agent execution.
  #
  # Contains the task, goals, constraints, and available tools
  # for guiding agent decision-making and planning.
  #
  # @see Types::PlanContext
  PlanContext = Types::PlanContext

  # @!endgroup

  # ============================================================
  # Schema and Configuration
  # ============================================================

  # @!group Configuration

  # Input schema definition for tools and agents.
  #
  # Describes parameter names, types, descriptions, and
  # requirements for tool inputs. Used for tool introspection
  # and parameter validation.
  #
  # @see Types::InputSchema
  InputSchema = Types::InputSchema

  # @!endgroup

  # ============================================================
  # Tool Execution Statistics
  # ============================================================

  # @!group Statistics

  # Statistics for a single tool execution.
  #
  # Tracks call count, success rate, error count, and average
  # execution time for monitoring tool reliability.
  #
  # @see Types::ToolStats
  ToolStats = Types::ToolStats

  # Aggregator for tool execution statistics.
  #
  # Mutable collection for accumulating statistics across
  # multiple tool calls. Use in monitoring and observability.
  #
  # @see Runtime::ToolStatsAggregator
  ToolStatsAggregator = Runtime::ToolStatsAggregator

  # @!endgroup

  # ============================================================
  # Ractor Types (Concurrent Execution)
  # ============================================================

  # @!group Ractor

  # Task to be executed in a Ractor.
  #
  # Represents work units sent to isolated Ractor processes
  # for concurrent execution with message passing.
  #
  # @see Types::RactorTask
  RactorTask = Types::RactorTask

  # Successful result from Ractor execution.
  #
  # Indicates a Ractor task completed with a value result.
  #
  # @see Types::RactorSuccess
  RactorSuccess = Types::RactorSuccess

  # Failed result from Ractor execution.
  #
  # Indicates a Ractor task failed with an error.
  #
  # @see Types::RactorFailure
  RactorFailure = Types::RactorFailure

  # Message passed between Ractors.
  #
  # Union type for task, success, and failure messages
  # in Ractor-based concurrent execution.
  #
  # @see Types::RactorMessage
  RactorMessage = Types::RactorMessage

  # Valid message types for Ractor communication.
  #
  # Contains the list of allowed message types that Ractors
  # can send and receive.
  #
  # @see Types::RACTOR_MESSAGE_TYPES
  RACTOR_MESSAGE_TYPES = Types::RACTOR_MESSAGE_TYPES

  # Result from orchestrator execution across Ractors.
  #
  # Contains results from all sub-agents/tasks run in parallel
  # Ractor processes during orchestration.
  #
  # @see Types::OrchestratorResult
  OrchestratorResult = Types::OrchestratorResult

  # @!endgroup

  # ============================================================
  # Type System Modules
  # ============================================================

  # @!group Type Modules

  # Message role enumeration.
  #
  # Defines valid roles for chat messages: :user, :assistant, :system.
  # Used for structuring conversation history.
  #
  # @see Types::MessageRole
  MessageRole = Types::MessageRole

  # Execution outcome enumeration.
  #
  # Defines result states: :success, :failure, :error, :partial.
  # Used for tracking task and step completion status.
  #
  # @see Types::Outcome
  Outcome = Types::Outcome

  # Execution plan state enumeration.
  #
  # Defines planning states: :planning, :executing, :reviewing, :complete.
  # Used for tracking agent planning and execution progress.
  #
  # @see Types::PlanState
  PlanState = Types::PlanState

  # Callback hook enumeration.
  #
  # Defines event types: :step_complete, :tool_call, :error, etc.
  # Used for registering agent lifecycle listeners.
  #
  # @see Types::Callbacks
  Callbacks = Types::Callbacks

  # @!endgroup

  # ============================================================
  # Runtime State
  # ============================================================

  # @!group Runtime

  # Agent execution memory and history.
  #
  # Maintains conversation history, step records, and token tracking
  # throughout an agent's lifecycle. Mutable collection for building
  # up execution state.
  #
  # @see Runtime::AgentMemory
  AgentMemory = Runtime::AgentMemory

  # @!endgroup

  # ============================================================
  # Execution Outcomes
  # ============================================================

  # @!group Outcomes

  # Outcome of tool or agent execution.
  #
  # Composition of result and status predicates for evaluating
  # whether a task succeeded, failed, or produced partial results.
  #
  # @see Types::ExecutionOutcome
  ExecutionOutcome = Types::ExecutionOutcome

  # Outcome of executor-level code execution.
  #
  # Specialized outcome type for sandboxed Ruby code execution
  # (Ruby, Docker, or Ractor executors).
  #
  # @see Types::ExecutorExecutionOutcome
  ExecutorExecutionOutcome = Types::ExecutorExecutionOutcome

  # Predicates for evaluating execution outcomes.
  #
  # Helper methods for checking outcome conditions:
  # succeeded?, failed?, partial?, etc.
  #
  # @see Types::OutcomePredicates
  OutcomePredicates = Types::OutcomePredicates

  # @!endgroup

  # ============================================================
  # Logging, Security, Observability
  # ============================================================

  # @!group Utilities and Infrastructure

  # Structured logging for agent execution and debugging.
  #
  # Provides log levels, filtering, and formatting optimized for
  # agent trace logging. Use for observing agent behavior.
  #
  # @example Log an agent step
  #   AgentLogger.info("Step complete", step_id: "step_1", duration: 0.5)
  #
  # @see Telemetry::AgentLogger
  AgentLogger = Telemetry::AgentLogger

  # Detects and prevents prompt injection attacks.
  #
  # Analyzes user input for malicious patterns attempting to
  # manipulate agent behavior or bypass safety guidelines.
  # Can sanitize or raise errors.
  #
  # @example Validate user input
  #   PromptSanitizer.validate!(user_prompt)
  #   # Raises PromptInjectionError if injection detected
  #
  # @example Sanitize suspicious input
  #   safe = PromptSanitizer.sanitize(user_prompt, mode: :strict)
  #
  # @see Security::PromptSanitizer
  PromptSanitizer = Security::PromptSanitizer

  # Redacts secrets and sensitive data from logs and output.
  #
  # Removes API keys, tokens, passwords, and other sensitive
  # information before logging or displaying agent output.
  # Recognizes common secret patterns.
  #
  # @example Redact API keys from a string
  #   text = "Key: sk-1234567890abcdef1234567890abcdef"
  #   SecretRedactor.redact(text)
  #   # => "Key: [REDACTED]"
  #
  # @example Redact sensitive hash keys
  #   config = { api_key: "secret123", url: "https://example.com" }
  #   SecretRedactor.redact(config)
  #   # => {"api_key"=>"[REDACTED]", "url"=>"https://example.com"}
  #
  # @see Security::SecretRedactor
  SecretRedactor = Security::SecretRedactor

  # Data collection and observability instrumentation.
  #
  # Records execution events for agents, tools, and orchestrators.
  # Integrates with OpenTelemetry for distributed tracing.
  #
  # @see Telemetry::Instrumentation
  Instrumentation = Telemetry::Instrumentation

  # Pattern matching utilities for parsing LLM responses.
  #
  # Extracts code blocks, JSON, structured data, and answers
  # from LLM outputs. Essential for CodeAgent and ToolAgent.
  #
  # @example Extract Ruby code from LLM response
  #   code = PatternMatching.extract_code(response)
  #   executor.run(code)
  #
  # @example Extract JSON tool calls
  #   calls = PatternMatching.extract_json(response, as: :tool_calls)
  #
  # @see Utilities::PatternMatching
  PatternMatching = Utilities::PatternMatching

  # Dynamic system prompt generation.
  #
  # Creates optimized prompts for CodeAgent and ToolAgent,
  # including tool descriptions and examples. Tuned for small models.
  #
  # @example Generate a code agent prompt
  #   prompt = Prompts.code_agent(
  #     tools: [calculator, search],
  #     custom: "Be concise"
  #   )
  #
  # @see Utilities::Prompts
  Prompts = Utilities::Prompts

  # Answer comparison and similarity evaluation.
  #
  # Compares agent outputs against expected answers to measure
  # accuracy. Extracts entities and computes semantic similarity.
  # Useful for evaluation harnesses.
  #
  # @example Compare answers
  #   similarity = Comparison.similarity(expected_answer, agent_output)
  #   puts "#{(similarity * 100).round}% match"
  #
  # @example Extract key entities
  #   entities = Comparison.extract_entities(text)
  #   # => Set of detected proper nouns, numbers, quoted phrases
  #
  # @see Utilities::Comparison
  Comparison = Utilities::Comparison

  # Confidence estimation for agent responses.
  #
  # Analyzes outputs to estimate response quality based on:
  # - Language patterns (confidence markers, uncertainty hedges)
  # - Execution metrics (steps taken, error rate)
  # - Content quality (entity density, response length)
  #
  # @example Estimate confidence
  #   score = Confidence.estimate(
  #     agent_output,
  #     steps_taken: 3,
  #     max_steps: 10
  #   )
  #   # => 0.75 (confidence score 0.0-1.0)
  #
  # @example Check confidence level
  #   level = Confidence.level(output, steps_taken: 3, max_steps: 10)
  #   # => :high, :medium, or :low
  #
  # @see Utilities::Confidence
  Confidence = Utilities::Confidence

  # HTTP utilities for making requests from agents.
  #
  # Provides RFC 7231 compliant User-Agent strings for identifying
  # agent requests. Used by web search and browser tools.
  #
  # @see Http::UserAgent
  UserAgent = Http::UserAgent

  # @!endgroup

  # ============================================================
  # Testing and Benchmarking
  # ============================================================

  # Testing and benchmarking framework (autoloaded on first use).
  #
  # Provides utilities for model evaluation, compatibility testing,
  # and benchmark runs. Autoloaded to avoid startup overhead.
  #
  # @see Testing Model evaluation and compatibility testing
  autoload :Testing, "smolagents/testing"
end

# ============================================================
# Auto-activate Interactive Mode
# ============================================================
#
# When loaded in an interactive session (IRB, Pry, Rails console),
# automatically scan for models and show a helpful welcome message.
# This runs after all constants are defined.
#
# Set SMOLAGENTS_QUIET=1 to disable the welcome message.
# Set SMOLAGENTS_NO_DISCOVER=1 to skip discovery entirely.

if Smolagents::Interactive.session? && !ENV["SMOLAGENTS_NO_DISCOVER"]
  Smolagents::Interactive.activate!(quiet: ENV.fetch("SMOLAGENTS_QUIET", nil))
end
