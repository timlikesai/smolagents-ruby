require_relative "planning/templates"

module Smolagents
  module Concerns
    # Agent planning with periodic strategy updates (Pre-Act pattern, arXiv:2505.09970).
    # Generates initial plan before first action, then updates every N steps.
    # @see Planning::Templates For prompt templates
    # @see PlanContext For plan state
    module Planning
      TEMPLATES = Templates::TEMPLATES

      def self.included(base)
        base.attr_reader :planning_interval, :planning_templates
        base.extend ClassMethods
      end

      module ClassMethods
        def default_planning_templates = @default_planning_templates ||= Templates::TEMPLATES.dup
        def configure_planning_templates(tpls) = @default_planning_templates = Templates::TEMPLATES.merge(tpls)
      end

      private

      def initialize_planning(planning_interval: nil, planning_templates: nil, memory_reader: nil)
        @planning_interval = planning_interval
        @planning_templates = (planning_templates || self.class.default_planning_templates).freeze
        @plan_context = PlanContext.uninitialized
        @planning_memory_reader = memory_reader || method(:default_memory_reader)
      end

      def default_memory_reader = @memory
      def planning_memory = @planning_memory_reader.call

      def execute_initial_planning_if_needed(task)
        return unless @planning_interval&.positive?
        return if @plan_context.initialized?

        planning_step = execute_initial_planning_step(task, 0)
        planning_memory.add_step(planning_step)
        yield planning_step.token_usage if block_given?
      end

      def execute_planning_step_if_needed(task, current_step, step_number)
        return unless @planning_interval&.positive?
        return unless @plan_context.initialized?
        return unless (step_number % @planning_interval).zero?

        planning_step = execute_update_planning_step(task, current_step, step_number)
        planning_memory.add_step(planning_step)
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
        tools_desc = @tools.values.map { |t| "- #{t.name}: #{t.description}" }.join("\n")
        [ChatMessage.system(@planning_templates[:planning_system]),
         ChatMessage.user(format(@planning_templates[:initial_plan], task:, tools: tools_desc))]
      end

      def execute_update_planning_step(task, last_step, step_number)
        timing = Timing.start_now
        messages = build_update_planning_messages(task, last_step)
        response = @model.generate(messages)
        @plan_context = @plan_context.update(response.content, at_step: step_number) # rubocop:disable Style/RedundantSelfAssignment
        build_planning_step(messages, response, timing)
      end

      def build_update_planning_messages(task, last_step)
        obs = last_step&.observations || "No observations yet."
        steps = summarize_steps.then { it.empty? ? "None yet." : it }
        pre = format(@planning_templates[:update_plan_pre], task:)
        post = format(@planning_templates[:update_plan_post], task:, steps:, observations: obs,
                                                              plan: @plan_context.plan || "No plan yet.")
        [ChatMessage.system(@planning_templates[:planning_system]), ChatMessage.user("#{pre}\n\n#{post}")]
      end

      def build_planning_step(messages, response, timing)
        PlanningStep.new(model_input_messages: messages, model_output_message: response, plan: @plan_context.plan,
                         timing: timing.stop, token_usage: response.token_usage)
      end

      def summarize_steps(limit: nil)
        sums = planning_memory.action_steps.to_a.filter_map do |s|
          "Step #{s.step_number}: #{s.observations&.slice(0, 100)}..." if s.is_a?(ActionStep)
        end
        (limit ? sums.first(limit) : sums).join("\n")
      end

      def current_plan = @plan_context.plan
      def plan_context = @plan_context
    end
  end
end
