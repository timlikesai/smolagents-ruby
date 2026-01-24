module Smolagents
  module Types
    # Immutable goal with status tracking and hierarchy support.
    #
    # Goals track what the agent is trying to accomplish. They form a tree
    # structure (via parent_id) and progress through states.
    #
    # @example Creating a root goal
    #   goal = Goal.create(description: "Find Ruby 4.0 release notes")
    #   goal.root?     # => true
    #   goal.active?   # => true
    #
    # @example Completing a goal with evidence
    #   completed = goal.complete(evidence: "Found 3 sources")
    #   completed.completed?  # => true
    #   completed.progress    # => "Found 3 sources"
    #
    # @example Creating a subgoal
    #   subgoal = Goal.create(description: "Search web", parent_id: goal.id)
    #   subgoal.root?  # => false
    # Valid goal states
    GOAL_STATUSES = %i[active blocked completed abandoned].freeze

    Goal = Data.define(:id, :description, :status, :progress, :parent_id, :created_at) do

      # Creates a new active goal with generated ID.
      # @param description [String] What the goal aims to achieve
      # @param parent_id [String, nil] Parent goal ID for subgoals
      # @param progress [String, nil] Initial progress note
      # @return [Goal]
      def self.create(description:, parent_id: nil, progress: nil)
        new(
          id: "goal_#{SecureRandom.hex(4)}",
          description:,
          status: :active,
          progress:,
          parent_id:,
          created_at: Time.now
        )
      end

      # @return [Boolean] true if this is a root goal (no parent)
      def root? = parent_id.nil?

      # @return [Boolean] true if goal is active
      def active? = status == :active

      # @return [Boolean] true if goal is blocked
      def blocked? = status == :blocked

      # @return [Boolean] true if goal is completed
      def completed? = status == :completed

      # @return [Boolean] true if goal was abandoned
      def abandoned? = status == :abandoned

      # @return [Boolean] true if goal is still open (active or blocked)
      def open? = active? || blocked?

      # @return [Boolean] true if goal is closed (completed or abandoned)
      def closed? = completed? || abandoned?

      # Marks goal as completed with evidence of completion.
      # @param evidence [String] Description of what was achieved
      # @return [Goal] New goal instance with completed status
      def complete(evidence:) = with(status: :completed, progress: evidence)

      # Marks goal as blocked with reason.
      # @param reason [String] Why the goal is blocked
      # @return [Goal] New goal instance with blocked status
      def block(reason:) = with(status: :blocked, progress: reason)

      # Unblocks a blocked goal, returning to active.
      # @return [Goal] New goal instance with active status
      def unblock = with(status: :active)

      # Abandons the goal with reason.
      # @param reason [String] Why the goal was abandoned
      # @return [Goal] New goal instance with abandoned status
      def abandon(reason:) = with(status: :abandoned, progress: reason)

      # Updates progress without changing status.
      # @param note [String] Progress description
      # @return [Goal] New goal instance with updated progress
      def update_progress(note) = with(progress: note)

      # @return [Hash] Goal as hash for serialization
      def to_h
        { id:, description:, status:, progress:, parent_id:, created_at: created_at.iso8601 }
      end

      # @return [String] Compact string representation
      def to_s = "[#{status}] #{description}"
    end
  end
end
