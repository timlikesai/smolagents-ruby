require_relative "smolagents/version"
require_relative "smolagents/errors"
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

# Smolagents: Delightfully simple agents that think in Ruby.
#
# Smolagents provides a complete framework for building AI agents in Ruby.
# It includes:
#
# - **Agents**: CodeAgent (writes Ruby code), ToolAgent (JSON tool calls)
# - **Models**: OpenAI, Anthropic, LiteLLM, and local model support
# - **Tools**: Built-in tools for search, web visits, and custom tool creation
# - **Builders**: Fluent API for agent and team configuration
# - **Pipeline**: Composable tool execution chains
# - **Orchestrators**: Multi-agent coordination and sub-agent management
# - **Executors**: Sandboxed Ruby code execution (Ruby, Docker, Ractor)
# - **Telemetry**: Event-driven observability and tracing
# - **Persistence**: Agent state serialization and loading
#
# @example Creating and running a code agent
#   agent = Smolagents.code
#     .model { OpenAIModel.new(model_id: "gpt-4") }
#     .tools(:web_search, :visit_webpage)
#     .build
#
#   result = agent.run("Find recent Ruby news")
#
# @example Creating a tool-calling agent
#   agent = Smolagents.tool
#     .model { OpenAIModel.new(model_id: "gpt-4") }
#     .tools(:web_search)
#     .build
#
# @example Composing tools with pipelines
#   result = Smolagents.run(:search, query: "Ruby 4.0")
#     .then(:visit_webpage) { |r| { url: r.first[:url] } }
#     .pluck(:content)
#     .run
#
# @see Agents Agent types and implementation
# @see Models LLM adapters and configurations
# @see Tools Tool system and built-in tools
# @see Pipeline Composable tool execution
# @see Builders Fluent configuration DSL
#
module Smolagents
  class << self
    # ============================================================
    # Agent Shortcuts - Ergonomic entry points
    # ============================================================

    # Creates a code agent builder.
    #
    # CodeAgent generates Ruby code to call tools, making it suitable for:
    # - Complex multi-step reasoning
    # - Writing and executing Ruby code
    # - Models with strong code generation capabilities
    #
    # The agent automatically includes the final_answer tool.
    #
    # @example Minimal agent
    #   Smolagents.code
    #     .model { OpenAI.gpt4 }
    #     .build
    #
    # @example With tools and event handlers
    #   Smolagents.code
    #     .model { LMStudio.llama3 }
    #     .tools(:web_search, :visit_webpage)
    #     .on(:step_complete) { |e| puts e }
    #     .max_steps(10)
    #     .build
    #
    # @return [Builders::AgentBuilder] Code agent builder (fluent interface)
    #
    # @see Builders::AgentBuilder Configuration options
    # @see Agents::CodeAgent Implementation details
    def code
      Builders::AgentBuilder.create(:code).tools(:final_answer)
    end

    # Creates a tool-calling agent builder.
    #
    # ToolAgent uses JSON-formatted tool calls, making it suitable for:
    # - Models with native tool use support (OpenAI, Claude, etc.)
    # - Reliable tool invocation
    # - Efficient multi-step tasks
    #
    # The agent automatically includes the final_answer tool.
    #
    # @example
    #   Smolagents.tool
    #     .model { OpenAI.gpt4 }
    #     .tools(:web_search)
    #     .max_steps(8)
    #     .build
    #
    # @return [Builders::AgentBuilder] Tool-calling agent builder (fluent interface)
    #
    # @see Builders::AgentBuilder Configuration options
    # @see Agents::ToolAgent Implementation details
    def tool
      Builders::AgentBuilder.create(:tool).tools(:final_answer)
    end

    # Creates a new agent builder with specified type.
    #
    # This is the generic form used internally by {#code} and {#tool}.
    # Most users should prefer the convenience methods instead.
    #
    # @param type [Symbol] Agent type (:code or :tool)
    # @return [Builders::AgentBuilder] New agent builder
    #
    # @example
    #   agent = Smolagents.agent(:code).model { ... }.build
    #
    # @see #code For code-generating agents
    # @see #tool For JSON tool-calling agents
    def agent(type)
      Builders::AgentBuilder.create(type)
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
    # @example Creating a research and writing team
    #   Smolagents.team
    #     .model { OpenAI.gpt4 }
    #     .agent(researcher, as: "researcher")
    #     .agent(writer, as: "writer")
    #     .coordinate("Research the topic, then write a summary")
    #     .build
    #
    # @return [Builders::TeamBuilder] New team builder (fluent interface)
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
    #   agent = Smolagents.code.model { ... }.tools(tool).build
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
  # @see Collections::ActionStepBuilder
  ActionStepBuilder = Collections::ActionStepBuilder

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
  # @see Collections::ToolStatsAggregator
  ToolStatsAggregator = Collections::ToolStatsAggregator

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
  # Collections and Memory
  # ============================================================

  # @!group Collections

  # Agent execution memory and history.
  #
  # Maintains conversation history, step records, and token tracking
  # throughout an agent's lifecycle. Mutable collection for building
  # up execution state.
  #
  # @see Collections::AgentMemory
  AgentMemory = Collections::AgentMemory

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
