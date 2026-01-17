# Core data types for agent execution.
#
# This file loads all the fundamental Data.define types used throughout
# the smolagents library. Each type is defined in its own file for
# maintainability and to follow the 100-line rule.
#
# == Types
#
# - {TokenUsage} - LLM token consumption (input/output/total)
# - {Timing} - Execution timing information
# - {RunContext} - Agent execution context and metadata
# - {ToolCall} - Single tool invocation specification
# - {ToolOutput} - Tool execution result
# - {RunResult} - Complete agent execution result
#
# @see Types::TokenUsage For token tracking
# @see Types::Timing For timing operations
# @see Types::RunContext For execution context
# @see Types::ToolCall For tool calls
# @see Types::ToolOutput For tool results
# @see Types::RunResult For agent run results

require_relative "token_usage"
require_relative "timing"
require_relative "run_context"
require_relative "tool_call"
require_relative "tool_output"
require_relative "run_result"
