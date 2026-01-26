require_relative "memory/masking"
require_relative "memory/step_filtering"
require_relative "memory/token_estimation"

module Smolagents
  module Runtime
    # Manages conversation history and step tracking for agents.
    #
    # AgentMemory stores all steps taken during an agent's execution, including
    # tasks, actions, planning steps, and observations. It provides methods to
    # convert the memory into message format for LLM context.
    #
    # @example Creating and using memory
    #   memory = AgentMemory.new("You are a helpful assistant.")
    #   memory.add_task("Calculate 2+2")
    #   memory << ActionStep.new(step_number: 0, ...)
    #   messages = memory.to_messages
    #
    # @see Types::ActionStep Represents a single action/observation cycle
    # @see Types::TaskStep Represents a task given to the agent
    class AgentMemory
      include Memory::Masking
      include Memory::StepFiltering
      include Memory::TokenEstimation

      # @return [Types::SystemPromptStep] The system prompt
      attr_reader :system_prompt

      # @return [Array<Step>] All steps in chronological order
      attr_reader :steps

      # @return [Types::MemoryConfig] Memory configuration
      attr_reader :config

      # Creates a new memory with the given system prompt.
      #
      # @param system_prompt [String] The system prompt for the agent
      # @param config [Types::MemoryConfig] Memory configuration
      def initialize(system_prompt, config: Types::MemoryConfig.default)
        @system_prompt = Types::SystemPromptStep.new(system_prompt:)
        @steps = []
        @config = config
      end

      # Clears all steps from memory (keeps system prompt).
      # @return [Array] Empty steps array
      def reset = @steps = []

      # Adds a task to the memory.
      #
      # @param task [String] The task description
      # @param additional_prompting [String, nil] Additional context to append
      # @param task_images [Array<String>, nil] Images for multimodal agents
      # @return [Types::TaskStep] The created task step
      def add_task(task, additional_prompting: nil, task_images: nil)
        full_task = additional_prompting ? "#{task}\n\n#{additional_prompting}" : task
        @steps << Types::TaskStep.new(task: full_task, task_images:)
      end

      # Converts memory to LLM message format.
      #
      # @param summary_mode [Boolean] Use condensed representations
      # @return [Array<ChatMessage>] Messages suitable for LLM context
      def to_messages(summary_mode: false)
        system_prompt.to_messages + steps_to_messages(summary_mode:)
      end

      # Returns memory statistics.
      # @return [Hash] Step counts, tokens, and budget status
      def stats = step_stats.merge(budget_stats)

      # Returns all steps in succinct hash format.
      # @return [Array<Hash>] Steps as minimal hashes
      def succinct_steps = steps.map(&:to_h)

      # Returns all steps in full hash format.
      # @return [Array<Hash>] Steps with full: true marker
      def full_steps = steps.map { |step| step.to_h.merge(full: true) }

      # Extracts all code from action steps.
      # @return [String] Concatenated code from all action steps
      def return_full_code
        action_steps.filter_map(&:code_action).to_a.join("\n\n")
      end

      # Adds a step to memory.
      # @param step [Step] Any step type
      # @return [Array<Step>] Updated steps array
      def add_step(step) = @steps << step

      alias << add_step

      private

      def step_stats
        { step_count: steps.count, action_step_count: action_steps.count,
          task_step_count: task_steps.count, planning_step_count: planning_steps.count }
      end

      def budget_stats
        { estimated_tokens:, budget: config.budget, over_budget: over_budget?,
          headroom:, strategy: config.strategy }
      end
    end
  end
end
