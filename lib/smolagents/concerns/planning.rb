module Smolagents
  module Concerns
    module Planning
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

      def self.included(base)
        base.attr_reader :planning_interval, :planning_templates
        base.extend ClassMethods
      end

      module ClassMethods
        def default_planning_templates
          @default_planning_templates ||= TEMPLATES.dup
        end

        def configure_planning_templates(templates)
          @default_planning_templates = TEMPLATES.merge(templates)
        end
      end

      private

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

      def execute_initial_planning_step(task, step_number)
        timing = Timing.start_now
        tools_description = @tools.map { |t| "- #{t.name}: #{t.description}" }.join("\n")

        messages = [
          ChatMessage.system(@planning_templates[:planning_system]),
          ChatMessage.user(format(@planning_templates[:initial_plan], task: task, tools: tools_description))
        ]

        response = @model.generate(messages)
        @plan_context = PlanContext.initial(response.content)

        PlanningStep.new(
          model_input_messages: messages,
          model_output_message: response,
          plan: @plan_context.plan,
          timing: timing.stop,
          token_usage: response.token_usage
        )
      end

      def execute_update_planning_step(task, last_step, step_number)
        timing = Timing.start_now
        steps_summary = summarize_steps
        observations = last_step&.observations || "No observations yet."

        pre_message = format(@planning_templates[:update_plan_pre], task: task)
        post_message = format(@planning_templates[:update_plan_post],
                              task: task,
                              steps: steps_summary.empty? ? "None yet." : steps_summary,
                              observations: observations,
                              plan: @plan_context.plan || "No plan yet.")

        messages = [
          ChatMessage.system(@planning_templates[:planning_system]),
          ChatMessage.user("#{pre_message}\n\n#{post_message}")
        ]

        response = @model.generate(messages)
        @plan_context = @plan_context.update(response.content, at_step: step_number)

        PlanningStep.new(
          model_input_messages: messages,
          model_output_message: response,
          plan: @plan_context.plan,
          timing: timing.stop,
          token_usage: response.token_usage
        )
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
