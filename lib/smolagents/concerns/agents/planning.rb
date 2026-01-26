require_relative "planning/templates"
require_relative "planning/divergence"

module Smolagents
  module Concerns
    # Agent planning with periodic strategy updates (Pre-Act pattern, arXiv:2505.09970).
    # Generates initial plan before first action, then updates every N steps.
    #
    # Plan content is provided to models via Context::Providers.planning,
    # which contributes to the orchestrated context at the STRATEGIC layer.
    #
    # @see Planning::Templates For prompt templates
    # @see PlanContext For plan state
    # @see Context::Providers.planning For context integration
    module Planning
      TEMPLATES = Templates::TEMPLATES

      def self.included(base)
        base.attr_reader :planning_interval, :planning_templates
        base.extend ClassMethods
        base.include Divergence
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
        initialize_divergence_tracking
      end

      def default_memory_reader = @memory

      # Get the memory instance for planning steps.
      # @return [AgentMemory] Memory instance for storing plan steps
      def planning_memory = @planning_memory_reader.call

      # Check if initial planning should be executed.
      # @return [Boolean] true if planning is enabled and not yet initialized
      def should_execute_initial_planning? = planning_enabled? && !@plan_context.initialized?

      # Check if a planning update should be executed at this step.
      # @param step_number [Integer] Current step number
      # @return [Boolean] true if at planning interval boundary
      def should_execute_planning_update?(step) = planning_enabled? && @plan_context.initialized? && at_interval?(step)

      def planning_enabled? = !!@planning_interval&.positive?

      def at_interval?(step) = (step % @planning_interval).zero?

      def execute_initial_planning(task)
        planning_step = execute_initial_planning_step(task, 0)
        planning_memory.add_step(planning_step)
        yield planning_step.token_usage if block_given?
      end

      def execute_planning_update(task, current_step, step_number)
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
        [ChatMessage.system(@planning_templates[:planning_system]),
         ChatMessage.user(format(@planning_templates[:initial_plan], task:, tools: tool_descriptions))]
      end

      def execute_update_planning_step(task, last_step, step_number)
        timing = Timing.start_now
        messages = build_update_planning_messages(task, last_step)
        response = @model.generate(messages)
        @plan_context = @plan_context.update(response.content, at_step: step_number) # rubocop:disable Style/RedundantSelfAssignment -- immutable update pattern, reassignment is intentional
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

      # Get the current plan text.
      # @return [String, nil] Current plan or nil if not initialized
      def current_plan = @plan_context.plan

      # Get the plan context with state and history.
      # @return [PlanContext] Current plan context
      def plan_context = @plan_context
    end
  end
end
