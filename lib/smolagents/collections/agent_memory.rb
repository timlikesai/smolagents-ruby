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
      # Initializes a new AgentMemory with an empty step list. The system prompt
      # becomes the initial message that provides agent context and instructions.
      #
      # @param system_prompt [String] The system prompt for the agent
      #
      # @example Creating memory
      #   memory = AgentMemory.new("You are a helpful assistant.")
      #   memory.add_task("Calculate 2+2")
      #
      # @see Types::SystemPromptStep System prompt representation
      def initialize(system_prompt)
        @system_prompt = Types::SystemPromptStep.new(system_prompt:)
        @steps = []
      end

      # Clears all steps from memory (keeps system prompt).
      #
      # Removes all steps from memory but preserves the system prompt.
      # Useful for resetting execution history for a new task with the same agent.
      #
      # @return [Array] Empty steps array
      #
      # @example Resetting memory
      #   memory.reset
      #   memory.steps.empty?  # => true
      #
      # @see #steps All current steps
      def reset = @steps = []

      # Adds a task to the memory.
      #
      # Creates a TaskStep representing the task given to the agent and adds it
      # to memory. Additional prompting (context) can be appended. Images can
      # be associated with the task for multimodal agents.
      #
      # @param task [String] The task description
      # @param additional_prompting [String, nil] Additional context to append
      # @param task_images [Array<String>, nil] Images associated with the task (URLs or base64)
      #
      # @return [Types::TaskStep] The created task step (now in memory)
      #
      # @example Adding a task
      #   memory.add_task("Find information about Ruby")
      #   memory.add_task(
      #     "Summarize the document",
      #     additional_prompting: "Focus on key points.",
      #     task_images: ["https://example.com/image.png"]
      #   )
      #
      # @see Types::TaskStep Immutable task representation
      # @see #add_step Add other step types to memory
      def add_task(task, additional_prompting: nil, task_images: nil)
        full_task = additional_prompting ? "#{task}\n\n#{additional_prompting}" : task
        @steps << Types::TaskStep.new(task: full_task, task_images:)
      end

      # Converts memory to LLM message format.
      #
      # Transforms the system prompt and all steps into a list of ChatMessage objects
      # suitable for passing to a language model's generate method. Summary mode can
      # be used to create condensed representations for efficiency.
      #
      # @param summary_mode [Boolean] If true, uses condensed step representations (default: false)
      #
      # @return [Array<ChatMessage>] Messages suitable for LLM context (ordered by timestamp)
      #
      # @example Getting messages for LLM
      #   messages = memory.to_messages
      #   model.generate(messages)
      #
      # @example Using summary mode
      #   messages = memory.to_messages(summary_mode: true)  # Condensed for efficiency
      #
      # @see Types::ChatMessage Message representation
      # @see Types::SystemPromptStep#to_messages System prompt as messages
      def to_messages(summary_mode: false)
        system_prompt.to_messages + steps.flat_map { |step| step.to_messages(summary_mode:) }
      end

      # Returns all steps in succinct hash format.
      #
      # Converts all steps to simple hash representations (minimal details).
      # Useful for serialization, logging, or inspection.
      #
      # @return [Array<Hash>] Steps as hashes with minimal details
      #
      # @example Getting succinct steps
      #   steps = memory.get_succinct_steps
      #   puts steps.first.inspect
      #   # => { step_number: 0, tool_calls: [...] }
      #
      # @see #get_full_steps Get detailed step representations
      # @see #steps Get Step objects directly
      def get_succinct_steps = steps.map(&:to_h)

      # Returns all steps in full hash format with additional detail.
      #
      # Converts all steps to detailed hash representations (all available data).
      # Useful for detailed logging, analysis, or preservation of all context.
      #
      # @return [Array<Hash>] Steps as hashes with full: true marker and all details
      #
      # @example Getting full steps
      #   steps = memory.get_full_steps
      #   puts steps.first.keys  # => includes all available data
      #
      # @see #get_succinct_steps Get minimal step representations
      # @see #steps Get Step objects directly
      def get_full_steps = steps.map { |step| step.to_h.merge(full: true) }

      # Extracts all code from action steps (for Code agents).
      #
      # Concatenates all code_action strings from ActionStep instances.
      # Useful for Code agents that write executable Ruby code.
      #
      # @return [String] Concatenated code from all action steps (separated by double newlines)
      #
      # @example Getting all code from steps
      #   code = memory.return_full_code
      #   eval(code)  # Execute all collected code
      #
      # @see Types::ActionStep Step type for code agents
      # @see Agents::CodeAgent Uses action code for execution
      def return_full_code = steps.filter_map { |step| step.code_action if step.is_a?(Types::ActionStep) && step.code_action }.join("\n\n")

      # Adds a step to memory.
      #
      # Appends a step (ActionStep, TaskStep, PlanningStep, or any Step type)
      # to the memory. Steps are stored in order and used to build LLM context.
      #
      # @param step [Step] Any step type (ActionStep, TaskStep, PlanningStep, FinalAnswerStep, etc.)
      #
      # @return [Array<Step>] Updated steps array
      #
      # @example Adding a step manually
      #   step = ActionStepBuilder.new(step_number: 0).build
      #   memory.add_step(step)
      #   # Or use the << alias:
      #   memory << step
      #
      # @see #<< Alias for add_step
      # @see Types::ActionStep Represents an action/observation cycle
      # @see Types::PlanningStep Represents planning/reasoning steps
      def add_step(step) = @steps << step

      # @!method <<(step)
      #   Alias for {#add_step}. Appends a step to memory using operator notation.
      #   @param step [Step] Step to add
      #   @return [Array<Step>] Updated steps array
      #   @see #add_step
      alias << add_step

      # Returns a lazy enumerator of action steps.
      #
      # Filters memory to return only ActionStep instances (tool calls and observations).
      # Returns a lazy enumerator for efficient processing of large step histories.
      #
      # @return [Enumerator::Lazy<Types::ActionStep>] Lazy enumerator of action steps
      #
      # @example Processing action steps
      #   memory.action_steps.each do |step|
      #     puts "Tool call: #{step.tool_calls.first.name}"
      #   end
      #
      # @example Counting action steps
      #   action_count = memory.action_steps.count
      #
      # @see Types::ActionStep Represents a tool call and observation
      # @see #planning_steps Get planning steps instead
      # @see #task_steps Get task steps instead
      def action_steps
        steps.lazy.select { |step| step.is_a?(Types::ActionStep) }
      end

      # Returns a lazy enumerator of planning steps.
      #
      # Filters memory to return only PlanningStep instances (reasoning/reflection).
      # Returns a lazy enumerator for efficient processing of large step histories.
      #
      # @return [Enumerator::Lazy<Types::PlanningStep>] Lazy enumerator of planning steps
      #
      # @example Processing planning steps
      #   memory.planning_steps.each do |step|
      #     puts "Plan: #{step.reasoning}"
      #   end
      #
      # @see Types::PlanningStep Represents planning/reasoning
      # @see #action_steps Get action steps instead
      # @see #task_steps Get task steps instead
      def planning_steps
        steps.lazy.select { |step| step.is_a?(Types::PlanningStep) }
      end

      # Returns a lazy enumerator of task steps.
      #
      # Filters memory to return only TaskStep instances (user tasks).
      # Returns a lazy enumerator for efficient processing of large step histories.
      #
      # @return [Enumerator::Lazy<Types::TaskStep>] Lazy enumerator of task steps
      #
      # @example Processing task steps
      #   memory.task_steps.each do |step|
      #     puts "Task: #{step.task}"
      #   end
      #
      # @see Types::TaskStep Represents a task given to the agent
      # @see #action_steps Get action steps instead
      # @see #planning_steps Get planning steps instead
      def task_steps
        steps.lazy.select { |step| step.is_a?(Types::TaskStep) }
      end
    end
  end
end
