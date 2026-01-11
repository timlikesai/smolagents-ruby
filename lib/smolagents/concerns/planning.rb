module Smolagents
  module Concerns
    module Planning
      PLANNING_PROMPT = <<~PROMPT
        Based on the task and your progress so far, create or update your plan.
        Task: %<task>s
        Previous steps taken:
        %<steps>s
        Current observations:
        %<observations>s
        Create a brief plan (3-5 bullet points) for completing this task:
      PROMPT

      def self.included(base)
        base.attr_reader :planning_interval
      end

      private

      def execute_planning_step_if_needed(task, current_step, step_number)
        return unless @planning_interval && (step_number % @planning_interval).zero?

        planning_step = execute_planning_step(task, current_step)
        @memory.add_step(planning_step)
        yield planning_step.token_usage if block_given?
      end

      def execute_planning_step(task, last_step)
        timing = Timing.start_now
        steps_summary = @memory.steps.select { |s| s.is_a?(ActionStep) }.map { |s| "Step #{s.step_number}: #{s.observations&.slice(0, 100)}..." }.join("\n")
        planning_messages = [
          ChatMessage.system("You are a planning assistant. Create concise, actionable plans."),
          ChatMessage.user(format(PLANNING_PROMPT, task: task, steps: steps_summary.empty? ? "None yet." : steps_summary, observations: last_step.observations || "No observations yet."))
        ]
        response = @model.generate(planning_messages)
        @current_plan = response.content
        PlanningStep.new(model_input_messages: planning_messages, model_output_message: response, plan: @current_plan, timing: timing.stop, token_usage: response.token_usage)
      end
    end
  end
end
