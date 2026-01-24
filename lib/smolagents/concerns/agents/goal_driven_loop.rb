module Smolagents
  module Concerns
    # Goal-driven iteration for the ReAct loop.
    #
    # Extends the standard ReAct loop with goal awareness:
    # - Updates goal progress after each step
    # - Checks goal completion as exit condition
    # - Emits goal progress events
    #
    # Designed to work with GoalTracking and EarlyYield concerns.
    # Include AFTER ReActLoop to override its behavior.
    #
    # @example Including in an agent
    #   class MyAgent
    #     include Concerns::GoalTracking
    #     include Concerns::ReActLoop
    #     include Concerns::GoalDrivenLoop
    #   end
    #
    # @see GoalTracking For goal management
    # @see EarlyYield For speculative tool execution
    module GoalDrivenLoop
      # Override after_step to track goal progress.
      #
      # Records what happened in this step as progress toward the goal.
      # Called after each step completes but before advancing context.
      #
      # @param task [String] Task description
      # @param step [ActionStep] Completed step
      # @param ctx [RunContext] Current context
      # @return [RunContext] Advanced context
      def after_step(task, step, ctx)
        record_goal_progress(step) if respond_to?(:current_goal)
        super
      end

      # Override check_step_completion to include goal state.
      #
      # Adds goal completion check alongside standard final_answer detection.
      # If current goal is marked complete (externally or via tool), finalize.
      #
      # @param task [String] Task description
      # @param step [ActionStep] Completed step
      # @param ctx [RunContext] Current context
      # @param memory [AgentMemory] History
      # @return [RunResult, nil] Result if done, nil to continue
      def check_step_completion(task, step, ctx, memory)
        # Check standard completion first (final_answer, evaluation)
        result = super
        return result if result

        # Check if goal was completed during step execution
        check_goal_completion(ctx, memory)
      end

      private

      # Record step result as goal progress.
      # @param step [ActionStep] Completed step
      def record_goal_progress(step)
        goal = current_goal
        return unless goal&.active?

        note = build_progress_note(step)
        update_goal_progress(goal, note) if note
        emit_goal_progress(goal, note) if note && emitting?
      end

      # Build a progress note from step output.
      # @param step [ActionStep] Completed step
      # @return [String, nil] Progress description
      def build_progress_note(step)
        return nil unless step.action_output

        output = step.action_output.to_s
        return nil if output.empty?

        # Truncate long outputs for progress tracking
        output.length > 100 ? "#{output[0, 97]}..." : output
      end

      # Check if goal completion should end the loop.
      #
      # Looks for completed root goals, since current_goal only returns
      # active goals. When a goal is completed during step execution,
      # we detect it here and finalize.
      #
      # @param ctx [RunContext] Current context
      # @param memory [AgentMemory] History
      # @return [RunResult, nil] Result if goal complete
      def check_goal_completion(ctx, memory)
        return unless respond_to?(:goal_store)

        # Find most recently completed root goal
        completed = goal_store.completed.reverse.find(&:root?)
        return unless completed

        # Goal was marked complete during execution (evidence stored in progress)
        finalize(:success, completed.progress, ctx, memory:)
      end

      # Emit goal progress event.
      # @param goal [Types::Goal] Current goal
      # @param _note [String] Progress note (included for API consistency)
      def emit_goal_progress(goal, _note)
        return unless defined?(Events::GoalProgress)

        emit_event(Events::GoalProgress.create(goal:, previous_progress: goal.progress))
      end

      # Check if event emission is available and enabled.
      # @return [Boolean]
      def emitting?
        respond_to?(:emit_event) && respond_to?(:emitting?) && super
      end
    end
  end
end
