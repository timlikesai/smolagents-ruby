module Smolagents
  module Collections
    # Manages conversation history and step tracking for agents.
    #
    # AgentMemory stores all steps taken during an agent's execution, including
    # tasks, actions, planning steps, and observations. It provides methods to
    # convert the memory into message format for LLM context.
    #
    # Memory is organized as:
    # - System prompt (always first)
    # - Steps (TaskStep, ActionStep, PlanningStep, FinalAnswerStep)
    #
    # @example Creating and using memory
    #   memory = AgentMemory.new("You are a helpful assistant.")
    #   memory.add_task("Calculate 2+2")
    #   memory << ActionStep.new(step_number: 0, ...)
    #   messages = memory.to_messages
    #
    # @example Filtering steps by type
    #   memory.action_steps.each { |step| puts step.observations }
    #   memory.planning_steps.count
    #
    # @see Types::ActionStep Represents a single action/observation cycle
    # @see Types::TaskStep Represents a task given to the agent
    # @see Types::PlanningStep Represents planning/reasoning steps
    class AgentMemory
      # @return [Types::SystemPromptStep] The system prompt for this conversation
      attr_reader :system_prompt

      # @return [Array<Step>] All steps in chronological order
      attr_reader :steps

      # Creates a new memory with the given system prompt.
      #
      # @param system_prompt [String] The system prompt for the agent
      def initialize(system_prompt)
        @system_prompt = Types::SystemPromptStep.new(system_prompt:)
        @steps = []
      end

      # Clears all steps from memory (keeps system prompt).
      #
      # @return [Array] Empty steps array
      def reset = @steps = []

      # Adds a task to the memory.
      #
      # @param task [String] The task description
      # @param additional_prompting [String, nil] Additional context to append
      # @param task_images [Array<String>, nil] Images associated with the task
      # @return [Types::TaskStep] The created task step
      def add_task(task, additional_prompting: nil, task_images: nil)
        full_task = additional_prompting ? "#{task}\n\n#{additional_prompting}" : task
        @steps << Types::TaskStep.new(task: full_task, task_images:)
      end

      # Converts memory to LLM message format.
      #
      # @param summary_mode [Boolean] If true, uses condensed step representations
      # @return [Array<ChatMessage>] Messages suitable for LLM context
      def to_messages(summary_mode: false)
        system_prompt.to_messages + steps.flat_map { |step| step.to_messages(summary_mode:) }
      end

      # Returns all steps in succinct hash format.
      #
      # @return [Array<Hash>] Steps as hashes
      def get_succinct_steps = steps.map(&:to_h)

      # Returns all steps in full hash format with additional detail.
      #
      # @return [Array<Hash>] Steps as hashes with full: true marker
      def get_full_steps = steps.map { |step| step.to_h.merge(full: true) }

      # Extracts all code from action steps (for Code agents).
      #
      # @return [String] Concatenated code from all action steps
      def return_full_code = steps.filter_map { |step| step.code_action if step.is_a?(Types::ActionStep) && step.code_action }.join("\n\n")

      # Adds a step to memory.
      #
      # @param step [Step] Any step type (ActionStep, TaskStep, etc.)
      # @return [Array<Step>] Updated steps array
      def add_step(step) = @steps << step

      # @!method <<(step)
      #   Alias for {#add_step}.
      #   @see #add_step
      alias << add_step

      # Returns a lazy enumerator of action steps.
      #
      # @return [Enumerator::Lazy<Types::ActionStep>] Filtered action steps
      def action_steps
        steps.lazy.select { |step| step.is_a?(Types::ActionStep) }
      end

      # Returns a lazy enumerator of planning steps.
      #
      # @return [Enumerator::Lazy<Types::PlanningStep>] Filtered planning steps
      def planning_steps
        steps.lazy.select { |step| step.is_a?(Types::PlanningStep) }
      end

      # Returns a lazy enumerator of task steps.
      #
      # @return [Enumerator::Lazy<Types::TaskStep>] Filtered task steps
      def task_steps
        steps.lazy.select { |step| step.is_a?(Types::TaskStep) }
      end
    end
  end
end
