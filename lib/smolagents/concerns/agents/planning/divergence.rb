module Smolagents
  module Concerns
    module Planning
      # Plan divergence detection and tracking.
      #
      # Tracks how well actual execution aligns with the generated plan.
      # Emits PlanDivergence events when significant drift is detected.
      module Divergence
        # Divergence levels based on off-topic step count
        DIVERGENCE_THRESHOLDS = {
          mild: 1,
          moderate: 3,
          severe: 5
        }.freeze

        private

        def initialize_divergence_tracking
          @off_topic_steps = 0
          @last_plan_alignment = 1.0
        end

        # Tracks whether a step aligns with the current plan.
        #
        # @param step [ActionStep] The completed step
        # @param task [String] The original task
        # @return [void]
        def track_plan_alignment(step, task)
          return unless @planning_interval&.positive?
          return unless @plan_context&.initialized?

          alignment = estimate_step_alignment(step)
          @last_plan_alignment = alignment

          if alignment < 0.5
            @off_topic_steps += 1
            emit_divergence_if_needed(task)
          else
            @off_topic_steps = [0, @off_topic_steps - 1].max
          end
        end

        # Estimates how well a step aligns with the plan.
        #
        # @param step [ActionStep] The step to evaluate
        # @return [Float] Alignment score 0.0-1.0
        def estimate_step_alignment(step)
          return 1.0 unless step_has_tracking_info?(step)
          return 1.0 if @plan_context.plan.nil?
          return 1.0 if step_aligns_with_plan?(step)

          0.4
        end

        # Check if step has required tracking information.
        # @param step [ActionStep] Step to check
        # @return [Boolean] True if step has tool_calls and observations
        def step_has_tracking_info?(step)
          step.respond_to?(:tool_calls) && step.respond_to?(:observations)
        end

        # Check if step aligns with current plan.
        # @param step [ActionStep] Step to evaluate
        # @return [Boolean] True if step matches plan or is final answer
        def step_aligns_with_plan?(step)
          tools_mentioned_in_plan?(step) || final_answer_step?(step)
        end

        # Check if any tools in step were mentioned in the plan.
        # @param step [ActionStep] Step containing tool calls
        # @return [Boolean] True if plan mentions tools from this step
        def tools_mentioned_in_plan?(step)
          plan_text = @plan_context.plan.downcase
          extract_tool_names(step).any? { |name| plan_text.include?(name.downcase) }
        end

        # Extract tool names from a step.
        # @param step [ActionStep] Step with tool_calls
        # @return [Array<String>] Tool names used in step
        def extract_tool_names(step)
          (step.tool_calls || []).map { |tc| tc.respond_to?(:name) ? tc.name.to_s : tc.to_s }
        end

        # Check if step is a final answer step.
        # @param step [ActionStep] Step to check
        # @return [Boolean] True if step marks task completion
        def final_answer_step?(step)
          step.respond_to?(:is_final_answer) && step.is_final_answer
        end

        def emit_divergence_if_needed(_task)
          level = divergence_level
          return unless level

          emit(Events::PlanDivergence.create(
                 level:,
                 task_relevance: @last_plan_alignment,
                 off_topic_count: @off_topic_steps
               ))
        end

        # Determine divergence level from off-topic step count.
        # @return [Symbol, nil] Divergence level (:mild, :moderate, :severe) or nil if none
        def divergence_level
          case @off_topic_steps
          when 0 then nil
          when 1..2 then :mild
          when 3..4 then :moderate
          else :severe
          end
        end
      end
    end
  end
end
