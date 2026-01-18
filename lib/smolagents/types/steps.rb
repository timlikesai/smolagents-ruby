# Step types for agent execution traces.
#
# This module provides immutable Data.define types representing
# the various steps in agent execution:
#
# - {ActionStep} - Single action in the ReAct loop
# - {TaskStep} - User task/request
# - {PlanningStep} - Planning phase output
# - {SystemPromptStep} - System prompt setup
# - {FinalAnswerStep} - Task completion
# - {NullStep} - Null object for empty/failed parsing
#
# All step types support:
# - +to_h+ for serialization
# - +to_messages+ for LLM context conversion
# - +deconstruct_keys+ for pattern matching
#
# @example Pattern matching on steps
#   case step
#   in ActionStep[tool_calls:] if tool_calls.any?
#     execute_tools(tool_calls)
#   in FinalAnswerStep[output:]
#     return output
#   in NullStep[reason:]
#     log_parse_failure(reason)
#   end
#
# @see ActionStepBuilder Mutable builder for ActionStep
# @see AgentMemory Container for steps

require_relative "steps/action_step"
require_relative "steps/task_step"
require_relative "steps/planning_step"
require_relative "steps/system_prompt_step"
require_relative "steps/final_answer_step"
require_relative "steps/null_step"
