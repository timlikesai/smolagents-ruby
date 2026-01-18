require_relative "execution/step_execution"
require_relative "execution/code_generation"
require_relative "execution/code_parsing"
require_relative "execution/execution_context"
require_relative "execution/code_execution"
require_relative "execution/thread_pool"
require_relative "execution/error_feedback"
require_relative "execution/prompt_generation"

module Smolagents
  module Concerns
    # Execution concerns for agent step processing.
    #
    # This module namespace organizes concerns related to step execution
    # and code processing. All smolagents agents write Ruby code.
    #
    # @!group Concern Dependency Graph
    #
    # == Dependency Matrix
    #
    #   | Concern          | Depends On        | Depended By    | Auto-Includes                              |
    #   |------------------|-------------------|----------------|------------------------------------------- |
    #   | StepExecution    | Timing (types)    | CodeExecution  | -                                          |
    #   | CodeGeneration   | @model            | CodeExecution  | -                                          |
    #   | CodeParsing      | -                 | CodeExecution  | -                                          |
    #   | ExecutionContext | @tools, @executor | CodeExecution  | -                                          |
    #   | CodeExecution    | @model, @executor | AgentRuntime   | CodeGeneration, CodeParsing,               |
    #   |                  |                   |                | ExecutionContext                           |
    #   | ThreadPool       | -                 | AsyncTools     | -                                          |
    #   | ErrorFeedback    | ExecutionOracle   | -              | -                                          |
    #   | PromptGeneration | @tools            | AgentRuntime   | -                                          |
    #
    # == Sub-concern Composition
    #
    #   CodeExecution (primary composite)
    #       |
    #       +-- CodeGeneration: generate_code_response()
    #       |   - Requires: @model, @memory
    #       |   - Modifies: action_step.model_output_message
    #       |
    #       +-- CodeParsing: extract_code_from_response()
    #       |   - Modifies: action_step.observations (on error)
    #       |
    #       +-- ExecutionContext: build_execution_variables()
    #           - Requires: @tools, @executor, @authorized_imports
    #           - Provides: Variable scope for sandboxed execution
    #
    #   StepExecution (standalone)
    #       |
    #       +-- Provides: with_step_timing(), build_action_step()
    #       +-- Requires: @logger (optional, for error logging)
    #       +-- Uses: Timing type for duration tracking
    #
    # == Instance Variables Required
    #
    # *CodeExecution*:
    # - @model [Model] - LLM for generating code
    # - @executor [Executor] - Sandboxed code executor
    # - @max_steps [Integer] - Step budget for reminder messages
    # - @memory [AgentMemory] - For building message history
    # - @tools [Hash] - Available tools (for variable injection)
    # - @authorized_imports [Array] - Allowed gem requires (optional)
    #
    # *StepExecution*:
    # - @logger [Logger] - For error logging (optional)
    #
    # == No Circular Dependencies
    #
    # The execution concerns form a clean DAG:
    #   StepExecution --> [standalone]
    #   CodeGeneration --> [standalone]
    #   CodeParsing --> [standalone]
    #   ExecutionContext --> [standalone]
    #   CodeExecution --> CodeGeneration, CodeParsing, ExecutionContext
    #
    # @!endgroup
    #
    # == Available Concerns
    #
    # - {StepExecution} - Step timing, error handling, and ActionStep building
    # - {CodeGeneration} - Model calls and response capture
    # - {CodeParsing} - Code block extraction from model output
    # - {ExecutionContext} - Executor setup and variable management
    # - {CodeExecution} - Complete code execution pipeline (composes the above)
    # - {ThreadPool} - Thread pool for parallel tool execution
    # - {ErrorFeedback} - Structured error feedback via ExecutionOracle
    # - {PromptGeneration} - System prompt and tool description generation
    #
    # == Composition
    #
    # For most use cases, include {CodeExecution} which auto-includes
    # the smaller concerns:
    #
    #   class MyAgent
    #     include Concerns::ReActLoop
    #     include Concerns::CodeExecution
    #   end
    #
    # == Step Processing Flow
    #
    # A typical step:
    #
    # 1. {StepExecution#with_step_timing} creates ActionStep with timing
    # 2. {CodeGeneration#generate_code_response} calls model
    # 3. {CodeParsing#extract_code_from_response} finds code block
    # 4. {CodeExecution#execute_code_action} runs in sandbox
    # 5. Result written back to ActionStep
    #
    # @example Agent with execution support
    #   class MyAgent
    #     include Concerns::Execution
    #     include Concerns::ReActLoop
    #
    #     def step(task, step_number:)
    #       with_step_timing(step_number:) do |action_step|
    #         execute_step(action_step)
    #       end
    #     end
    #   end
    #
    # @see StepExecution For step timing and error handling
    # @see CodeExecution For code generation and sandboxed execution
    # @see Agents::AgentRuntime For a complete implementation
    module Execution
      def self.included(base)
        base.include(StepExecution)
      end
    end
  end
end
