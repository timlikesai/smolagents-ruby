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
require_relative "types/agent_memory"

# Re-export types at Smolagents module level for convenience.
# This allows code to use either Smolagents::ChatMessage or Smolagents::Types::ChatMessage.
module Smolagents
  # Data types
  TokenUsage = Types::TokenUsage
  Timing = Types::Timing
  RunContext = Types::RunContext
  ToolCall = Types::ToolCall
  ToolOutput = Types::ToolOutput
  RunResult = Types::RunResult

  # Chat messages
  ChatMessage = Types::ChatMessage
  IMAGE_MIME_TYPES = Types::IMAGE_MIME_TYPES

  # Steps
  ActionStep = Types::ActionStep
  ActionStepBuilder = Types::ActionStepBuilder
  TaskStep = Types::TaskStep
  PlanningStep = Types::PlanningStep
  SystemPromptStep = Types::SystemPromptStep
  FinalAnswerStep = Types::FinalAnswerStep

  # Agent types
  AgentType = Types::AgentType
  AgentText = Types::AgentText
  AgentImage = Types::AgentImage
  AgentAudio = Types::AgentAudio
  ALLOWED_IMAGE_FORMATS = Types::ALLOWED_IMAGE_FORMATS
  ALLOWED_AUDIO_FORMATS = Types::ALLOWED_AUDIO_FORMATS
  AGENT_TYPE_MAPPING = Types::AGENT_TYPE_MAPPING

  # Plan types
  PlanContext = Types::PlanContext

  # Input schema
  InputSchema = Types::InputSchema

  # Tool stats
  ToolStats = Types::ToolStats
  ToolStatsAggregator = Types::ToolStatsAggregator

  # Ractor types
  RactorTask = Types::RactorTask
  RactorSuccess = Types::RactorSuccess
  RactorFailure = Types::RactorFailure
  RactorMessage = Types::RactorMessage
  RACTOR_MESSAGE_TYPES = Types::RACTOR_MESSAGE_TYPES
  OrchestratorResult = Types::OrchestratorResult

  # Modules
  MessageRole = Types::MessageRole
  Outcome = Types::Outcome
  PlanState = Types::PlanState
  Callbacks = Types::Callbacks

  # Memory
  AgentMemory = Types::AgentMemory

  # Execution outcomes (composition pattern - outcomes contain results)
  ExecutionOutcome = Types::ExecutionOutcome
  ExecutorExecutionOutcome = Types::ExecutorExecutionOutcome
  OutcomePredicates = Types::OutcomePredicates
end
