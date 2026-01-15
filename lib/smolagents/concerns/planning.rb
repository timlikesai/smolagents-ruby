module Smolagents
  module Concerns
    # Agent planning with periodic strategy updates
    #
    # Enables agents to create and update execution plans before and during task execution.
    # Plans are regenerated at configurable intervals to adapt to new observations.
    #
    # Planning integrates with model generation for strategic planning assistance.
    # Plans are tracked in PlanContext which tracks staleness based on step count.
    #
    # @example With planning enabled
    #   agent = CodeAgent.new(
    #     model: model,
    #     tools: tools,
    #     planning_interval: 3  # Replan every 3 steps
    #   )
    #
    # @see PlanContext For plan state tracking
    # @see Timing For duration tracking
    module Planning
      # Default prompt templates for planning operations
      TEMPLATES = {
        initial_plan: <<~PROMPT,
          You are a planning assistant. Create a concise, actionable plan.

          Task: %<task>s

          Available tools: %<tools>s

          Create a brief plan (3-5 bullet points) for completing this task:
        PROMPT

        update_plan_pre: <<~PROMPT,
          You are updating your plan based on progress so far.

          Task: %<task>s
        PROMPT

        update_plan_post: <<~PROMPT,
          Previous steps taken:
          %<steps>s

          Current observations:
          %<observations>s

          Current plan:
          %<plan>s

          Update your plan if needed, or confirm it's still valid:
        PROMPT

        planning_system: "You are a planning assistant. Create concise, actionable plans."
      }.freeze

      # Hook called when module is included
      # @api private
      def self.included(base)
        base.attr_reader :planning_interval, :planning_templates
        base.extend ClassMethods
      end

      # Class-level configuration for planning
      module ClassMethods
        # Get default planning templates
        # @return [Hash] Planning templates
        def default_planning_templates
          @default_planning_templates ||= TEMPLATES.dup
        end

        # Configure custom planning templates
        # @param templates [Hash] Templates to merge with defaults
        # @return [void]
        def configure_planning_templates(templates)
          @default_planning_templates = TEMPLATES.merge(templates)
        end
      end

      private

      # Initialize planning state and templates
      #
      # @param planning_interval [Integer, nil] Steps between plan updates
      # @param planning_templates [Hash, nil] Custom prompt templates
      # @return [void]
      # @api private
      def initialize_planning(planning_interval: nil, planning_templates: nil)
        @planning_interval = planning_interval
        @planning_templates = (planning_templates || self.class.default_planning_templates).freeze
        @plan_context = PlanContext.uninitialized
      end

      def execute_planning_step_if_needed(task, current_step, step_number)
        return unless @plan_context.stale?(step_number, @planning_interval)

        planning_step = if @plan_context.initialized?
                          execute_update_planning_step(task, current_step, step_number)
                        else
                          execute_initial_planning_step(task, step_number)
                        end
        @memory.add_step(planning_step)
        yield planning_step.token_usage if block_given?
      end

      def execute_initial_planning_step(task, _step_number)
        timing = Timing.start_now
        messages = build_initial_planning_messages(task)
        response = @model.generate(messages)
        @plan_context = PlanContext.initial(response.content)
        build_planning_step(messages, response, timing)
      end

      def build_initial_planning_messages(task)
        tools_description = @tools.map { |tool| "- #{tool.name}: #{tool.description}" }.join("\n")
        [
          ChatMessage.system(@planning_templates[:planning_system]),
          ChatMessage.user(format(@planning_templates[:initial_plan], task:, tools: tools_description))
        ]
      end

      def execute_update_planning_step(task, last_step, step_number)
        timing = Timing.start_now
        messages = build_update_planning_messages(task, last_step)
        response = @model.generate(messages)
        @plan_context.update(response.content, at_step: step_number)
        build_planning_step(messages, response, timing)
      end

      def build_update_planning_messages(task, last_step)
        observations = last_step&.observations || "No observations yet."
        steps_summary = summarize_steps.then { it.empty? ? "None yet." : it }
        pre = format(@planning_templates[:update_plan_pre], task:)
        post = format(@planning_templates[:update_plan_post], task:, steps: steps_summary, observations:,
                                                              plan: @plan_context.plan || "No plan yet.")
        [ChatMessage.system(@planning_templates[:planning_system]), ChatMessage.user("#{pre}\n\n#{post}")]
      end

      def build_planning_step(messages, response, timing)
        PlanningStep.new(model_input_messages: messages, model_output_message: response, plan: @plan_context.plan,
                         timing: timing.stop, token_usage: response.token_usage)
      end

      def step_summaries
        Enumerator.new do |yielder|
          @memory.action_steps.each do |step|
            case step
            in ActionStep[step_number:, observations:]
              yielder << "Step #{step_number}: #{observations&.slice(0, 100)}..."
            end
          end
        end.lazy
      end

      def summarize_steps(limit: nil)
        enum = step_summaries
        enum = enum.first(limit) if limit
        enum.to_a.join("\n")
      end

      def current_plan
        @plan_context.plan
      end

      def plan_context
        @plan_context
      end
    end
  end
end
