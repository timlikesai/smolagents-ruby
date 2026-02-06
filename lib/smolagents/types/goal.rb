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
      # @raise [ArgumentError] If description is blank
      def self.create(description:, parent_id: nil, progress: nil)
        validate_description!(description)

        new(
          id: "goal_#{SecureRandom.hex(4)}",
          description:,
          status: :active,
          progress:,
          parent_id:,
          created_at: Time.now
        )
      end

      # Validates a status value against GOAL_STATUSES.
      # @param status [Symbol, String] Status to validate
      # @return [Boolean] True if valid
      # @raise [ArgumentError] If status is invalid
      def self.validate_status!(status)
        status_sym = status.to_sym
        return true if GOAL_STATUSES.include?(status_sym)

        raise ArgumentError, "Invalid goal status: #{status}. Valid: #{GOAL_STATUSES.join(", ")}"
      end

      # Checks if a status value is valid.
      # @param status [Symbol, String] Status to check
      # @return [Boolean] True if valid
      def self.valid_status?(status) = GOAL_STATUSES.include?(status.to_sym)

      # Validates description is not blank.
      # @param description [String] Description to validate
      # @raise [ArgumentError] If description is blank
      # @api private
      def self.validate_description!(description)
        return if description.is_a?(String) && !description.strip.empty?

        raise ArgumentError, "Goal description cannot be blank"
      end

      # Creates a Goal from external data with validation.
      #
      # Use this when reconstructing goals from serialized data where
      # status values need validation.
      #
      # @param id [String] Goal ID
      # @param description [String] Goal description
      # @param status [Symbol, String] Goal status (must be valid)
      # @param progress [String, nil] Progress note
      # @param parent_id [String, nil] Parent goal ID
      # @param created_at [Time, String] Creation timestamp
      # @return [Goal] Validated goal instance
      # @raise [ArgumentError] If status is invalid or description is blank
      def self.from_data(id:, description:, status:, progress: nil, parent_id: nil, created_at: Time.now)
        validate_description!(description)
        validate_status!(status)

        created = created_at.is_a?(String) ? Time.parse(created_at) : created_at

        new(id:, description:, status: status.to_sym, progress:, parent_id:, created_at: created)
      end

      include TypeSupport::StatePredicates

      state_predicates :status,
                       active: :active, blocked: :blocked,
                       completed: :completed, abandoned: :abandoned,
                       open: %i[active blocked], closed: %i[completed abandoned]

      # @return [Boolean] true if this is a root goal (no parent)
      def root? = parent_id.nil?

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
