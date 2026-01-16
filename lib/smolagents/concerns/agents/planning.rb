module Smolagents
  module Concerns
    # Agent planning with periodic strategy updates.
    # Plans are created before first action (Pre-Act) and updated at intervals.
    # @see PlanContext For plan state tracking
    module Planning # rubocop:disable Metrics/ModuleLength
      # Default templates based on Pre-Act research (arXiv:2505.09970).
      TEMPLATES = {
        initial_plan: <<~PROMPT,
          Create a step-by-step plan to complete this task.

          Task: %<task>s

          Available tools:
          %<tools>s

          Instructions:
          - Create 3-5 concrete steps
          - Each step should use one of the available tools
          - Be specific about what information to gather or actions to take
          - Number each step

          Plan:
        PROMPT

        update_plan_pre: <<~PROMPT,
          Review your progress and update your plan.

          Task: %<task>s
        PROMPT

        update_plan_post: <<~PROMPT,
          Progress so far:
          %<steps>s

          Latest observations:
          %<observations>s

          Current plan:
          %<plan>s

          Based on what you've learned, either:
          1. Confirm the plan is still valid and continue, OR
          2. Update the remaining steps based on new information

          Updated plan:
        PROMPT

        planning_system: "You are a strategic planning assistant. " \
                         "Create concise, actionable plans that map directly to available tools. " \
                         "Focus on concrete steps, not abstract strategies."
      }.freeze

      def self.included(base)
        base.attr_reader :planning_interval, :planning_templates
        base.extend ClassMethods
      end

      module ClassMethods
        def default_planning_templates = @default_planning_templates ||= TEMPLATES.dup
        def configure_planning_templates(templates) = @default_planning_templates = TEMPLATES.merge(templates)
      end

      private

      def initialize_planning(planning_interval: nil, planning_templates: nil)
        @planning_interval = planning_interval
        @planning_templates = (planning_templates || self.class.default_planning_templates).freeze
        @plan_context = PlanContext.uninitialized
      end

      # Pre-Act: Execute initial planning before first action step.
      def execute_initial_planning_if_needed(task)
        return unless @planning_interval&.positive?
        return if @plan_context.initialized?

        planning_step = execute_initial_planning_step(task, 0)
        @memory.add_step(planning_step)
        yield planning_step.token_usage if block_given?
      end

      def execute_planning_step_if_needed(task, current_step, step_number)
        return unless @planning_interval&.positive?
        return unless @plan_context.initialized?
        return unless (step_number % @planning_interval).zero?

        planning_step = execute_update_planning_step(task, current_step, step_number)
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
        tools_description = @tools.values.map { |tool| "- #{tool.name}: #{tool.description}" }.join("\n")
        [
          ChatMessage.system(@planning_templates[:planning_system]),
          ChatMessage.user(format(@planning_templates[:initial_plan], task:, tools: tools_description))
        ]
      end

      def execute_update_planning_step(task, last_step, step_number)
        timing = Timing.start_now
        messages = build_update_planning_messages(task, last_step)
        response = @model.generate(messages)
        @plan_context = @plan_context.update(response.content, at_step: step_number) # rubocop:disable Style/RedundantSelfAssignment -- PlanContext is immutable (Data.define)
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

      def current_plan = @plan_context.plan
      def plan_context = @plan_context
    end
  end
end
