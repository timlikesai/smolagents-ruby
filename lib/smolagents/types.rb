# Domain types and data structures for agents.
#
# The Types module defines immutable data structures (using Data.define) and
# enumerations for representing agents, tools, messages, steps, and execution
# outcomes. All types are designed for composition, immutability, and pattern
# matching support.
#
# == Core Data Types
#
# - {TokenUsage} - LLM token consumption (input/output/total)
# - {Timing} - Execution timing information
# - {RunContext} - Agent execution context and metadata
# - {ToolCall} - Single tool invocation specification
# - {ToolOutput} - Tool execution result
# - {RunResult} - Complete agent execution result
#
# == Messages
#
# - {ChatMessage} - Single message in conversation (role, content, images, audio)
# - {IMAGE_MIME_TYPES} - Supported image MIME types for multimodal messages
#
# == Steps
#
# - {ActionStep} - Agent action (tool calls)
# - {ActionStepBuilder} - Mutable builder for ActionStep
# - {TaskStep} - Task definition and context
# - {PlanningStep} - Planning output
# - {SystemPromptStep} - System prompt setup
# - {FinalAnswerStep} - Agent conclusion
#
# == Agent Types
#
# - {AgentType} - Enum for multimodal input types
# - {AgentText} - Text input type
# - {AgentImage} - Image input type with MIME type
# - {AgentAudio} - Audio input type with MIME type
# - {ALLOWED_IMAGE_FORMATS} - Supported image formats
# - {ALLOWED_AUDIO_FORMATS} - Supported audio formats
# - {AGENT_TYPE_MAPPING} - Type to class mapping
#
# == Planning and Context
#
# - {PlanContext} - Planning context (goals, constraints, state)
# - {PlanState} - Enum for plan execution state
#
# == Execution Outcomes
#
# - {ExecutionOutcome} - General execution result (success/failure/partial)
# - {ExecutorExecutionOutcome} - Executor-specific outcome with timing
# - {OutcomePredicates} - State machine predicates for outcomes
#
# == Schemas and Configuration
#
# - {InputSchema} - Tool parameter schema definition
# - {ToolStats} - Tool invocation statistics
# - {ToolStatsAggregator} - Statistics accumulator
#
# == Communication
#
# - {MessageRole} - Enum for message roles (user, assistant, system)
# - {Outcome} - Enum for execution outcomes
# - {Callbacks} - Enum for callback event types
#
# == Ractor Support
#
# - {RactorTask} - Task for Ractor execution
# - {RactorSuccess} - Successful Ractor result
# - {RactorFailure} - Failed Ractor result
# - {RactorMessage} - Message in Ractor protocol
# - {RACTOR_MESSAGE_TYPES} - Message type constants
# - {OrchestratorResult} - Orchestrator execution result
#
# == Memory
#
# - {AgentMemory} - Step history and context tracking
#
# == Design Principles
#
# - **Immutability**: All types use Data.define for frozen instances
# - **Composition**: Complex types composed from simpler ones
# - **Pattern Matching**: Full support for Ruby case/in expressions
# - **Re-exports**: Available at top-level Smolagents for convenience
#
# @example Using immutable types
#   message = Smolagents::ChatMessage.new(
#     role: :user,
#     content: "Hello, agent!",
#     images: []
#   )
#   # Message is frozen and safe to share across threads/Ractors
#
# @example Pattern matching on steps
#   case step
#   in ActionStep[tool_calls:] if tool_calls.any?
#     execute_tools(tool_calls)
#   in FinalAnswerStep[answer:]
#     return answer
#   end
#
# @example Accessing re-exported types
#   # Both forms work (convenience re-exports)
#   Smolagents::ChatMessage   # Re-exported for convenience
#   Smolagents::Types::ChatMessage  # Full path
#
# @see Types::ChatMessage For message structure
# @see Types::ActionStep For step structure
# @see Types::RunResult For agent output structure
module Smolagents
  module Types
  end
end

# Load all types into the Smolagents::Types module
require_relative "types/message_role"
require_relative "types/outcome"
require_relative "types/execution_outcome"
require_relative "types/executor_execution_outcome"
require_relative "types/plan_state"
require_relative "types/plan_context"
require_relative "types/input_schema"
require_relative "types/data_types"
require_relative "types/chat_message"
require_relative "types/steps"
require_relative "types/agent_types"
require_relative "types/tool_stats"
require_relative "types/callbacks"
require_relative "types/ractor_types"

# Load mutable collections (separate from immutable Data.define types)
require_relative "collections"

# NOTE: Type re-exports are defined in lib/smolagents.rb with full YARD documentation.
# This file only loads the type definitions; the convenience aliases are set up in the main module.
