# frozen_string_literal: true

module Smolagents
  module Concerns
    # Provides planning capabilities with customizable templates.
    #
    # Templates use format strings with named parameters:
    # - %<task>s - The current task
    # - %<steps>s - Summary of previous steps
    # - %<observations>s - Current observations
    # - %<tools>s - Available tools description
    # - %<plan>s - Current plan (for updates)
    module Planning
      # Default templates - can be overridden per-agent
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
        @current_plan = nil
      end

      def execute_planning_step_if_needed(task, current_step, step_number)
        return unless @planning_interval && (step_number % @planning_interval).zero?

        planning_step = if @current_plan.nil?
                          execute_initial_planning_step(task)
                        else
                          execute_update_planning_step(task, current_step)
                        end
        @memory.add_step(planning_step)
        yield planning_step.token_usage if block_given?
      end

      def execute_initial_planning_step(task)
        timing = Timing.start_now
        tools_description = @tools.map { |t| "- #{t.name}: #{t.description}" }.join("\n")

        messages = [
          ChatMessage.system(@planning_templates[:planning_system]),
          ChatMessage.user(format(@planning_templates[:initial_plan], task: task, tools: tools_description))
        ]

        response = @model.generate(messages)
        @current_plan = response.content

        PlanningStep.new(
          model_input_messages: messages,
          model_output_message: response,
          plan: @current_plan,
          timing: timing.stop,
          token_usage: response.token_usage
        )
      end

      def execute_update_planning_step(task, last_step)
        timing = Timing.start_now
        steps_summary = summarize_steps
        observations = last_step&.observations || "No observations yet."

        pre_message = format(@planning_templates[:update_plan_pre], task: task)
        post_message = format(@planning_templates[:update_plan_post],
                              task: task,
                              steps: steps_summary.empty? ? "None yet." : steps_summary,
                              observations: observations,
                              plan: @current_plan || "No plan yet.")

        messages = [
          ChatMessage.system(@planning_templates[:planning_system]),
          ChatMessage.user("#{pre_message}\n\n#{post_message}")
        ]

        response = @model.generate(messages)
        @current_plan = response.content

        PlanningStep.new(
          model_input_messages: messages,
          model_output_message: response,
          plan: @current_plan,
          timing: timing.stop,
          token_usage: response.token_usage
        )
      end

      def summarize_steps
        @memory.steps
               .select { |s| s.is_a?(ActionStep) }
               .map { |s| "Step #{s.step_number}: #{s.observations&.slice(0, 100)}..." }
               .join("\n")
      end

      def current_plan
        @current_plan
      end
    end
  end
end
