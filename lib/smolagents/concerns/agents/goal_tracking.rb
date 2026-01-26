require_relative "goal_tracking/store"

module Smolagents
  module Concerns
    # Goal tracking for agents with hierarchy and status management.
    #
    # Goals track what the agent is trying to accomplish. They form a tree
    # structure and progress through states (active → completed/abandoned).
    #
    # When an agent starts a task, a root goal is automatically created.
    # Subgoals can be added as the agent decomposes the work.
    #
    # @example Including in an agent
    #   class MyAgent
    #     include Concerns::GoalTracking
    #
    #     def initialize
    #       initialize_goal_tracking
    #     end
    #   end
    #
    # @see GoalTracking::Store For goal storage
    # @see Types::Goal For goal data structure
    module GoalTracking
      # Initialize goal tracking state.
      def initialize_goal_tracking
        @goal_store = Store.new
      end

      # @return [Store] The goal store
      attr_reader :goal_store

      # Get the current active goal.
      # @return [Types::Goal, nil]
      def current_goal = @goal_store&.current

      # Create a root goal from a task description.
      # Called automatically when agent.run() starts.
      # @param task [String] The task description
      # @return [Types::Goal] The created goal
      def create_goal_from_task(task)
        goal = Types::Goal.create(description: task)
        @goal_store.add(goal)
        goal
      end

      # Create a subgoal under the current goal.
      # @param description [String] What the subgoal aims to achieve
      # @param parent [Types::Goal, nil] Parent goal (defaults to current)
      # @return [Types::Goal] The created subgoal
      def create_subgoal(description, parent: nil)
        parent ||= current_goal
        raise ArgumentError, "No parent goal available" unless parent

        subgoal = Types::Goal.create(description:, parent_id: parent.id)
        @goal_store.add(subgoal)
        subgoal
      end

      # Complete a goal with evidence.
      # @param goal_or_id [Types::Goal, String] Goal or goal ID
      # @param evidence [String] Evidence of completion
      # @return [Types::Goal] Updated goal
      def complete_goal(goal_or_id, evidence:)
        id = goal_or_id.is_a?(Types::Goal) ? goal_or_id.id : goal_or_id
        @goal_store.update(id) { |g| g.complete(evidence:) }
      end

      # Update goal progress.
      # @param goal_or_id [Types::Goal, String] Goal or goal ID
      # @param note [String] Progress note
      # @return [Types::Goal] Updated goal
      def update_goal_progress(goal_or_id, note)
        id = goal_or_id.is_a?(Types::Goal) ? goal_or_id.id : goal_or_id
        @goal_store.update(id) { |g| g.update_progress(note) }
      end

      # Build goal context for LLM.
      # @return [String, nil] Formatted goal context
      def build_goal_context
        current = current_goal
        return nil unless current

        parts = ["Current goal: #{current.description}"]
        parts << "Progress: #{current.progress}" if current.progress

        completed = @goal_store.completed
        parts << "Completed: #{completed.size} goal(s)" if completed.any?

        parts.join("\n")
      end
    end
  end
end
