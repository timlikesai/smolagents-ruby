module Smolagents
  module Types
    # A labeled segment of trajectory steps for semantic compression.
    #
    # TrajectorySegment groups consecutive steps that share a common purpose
    # (e.g., search operations, error recovery, planning). This enables
    # targeted compression strategies based on step semantics rather than
    # treating all steps uniformly.
    #
    # @!attribute [r] label [Symbol] Segment type (:search, :tool_execution, :error_recovery, :planning)
    # @!attribute [r] steps [Array<Step>] Steps in this segment (frozen)
    # @!attribute [r] outcome [Symbol] Segment outcome (:success, :failure, :partial, :unknown)
    # @!attribute [r] start_step [Integer] First step number in segment
    # @!attribute [r] end_step [Integer] Last step number in segment
    # @!attribute [r] summary [String, nil] Optional summary text for compressed representation
    #
    # @example Creating a segment from steps
    #   segment = TrajectorySegment.from_steps(
    #     action_steps,
    #     label: :search,
    #     outcome: :success
    #   )
    #   segment.step_count  #=> 3
    #   segment.step_range  #=> 1..3
    #
    # @see Runtime::TrajectoryAnalyzer Analyzes steps into segments
    TrajectorySegment = Data.define(:label, :steps, :outcome, :start_step, :end_step, :summary) do
      # Creates a segment from an array of steps.
      #
      # @param steps [Array<Step>] Steps to include in segment
      # @param label [Symbol] Semantic label for the segment
      # @param outcome [Symbol] Outcome of the segment (:success, :failure, :partial, :unknown)
      # @return [TrajectorySegment, nil] New segment or nil if steps empty
      def self.from_steps(steps, label:, outcome: :unknown)
        return nil if steps.empty?

        new(
          label:,
          steps: steps.freeze,
          outcome:,
          start_step: extract_step_number(steps.first),
          end_step: extract_step_number(steps.last),
          summary: nil
        )
      end

      # Extracts step number from a step, returning nil for steps without numbers.
      def self.extract_step_number(step)
        step.respond_to?(:step_number) ? step.step_number : nil
      end

      # @return [Integer] Number of steps in this segment
      def step_count = steps.size

      # @return [Boolean] True if segment completed successfully
      def success? = outcome == :success

      # @return [Boolean] True if segment failed
      def failure? = outcome == :failure

      # @return [Boolean] True if segment had partial success
      def partial? = outcome == :partial

      # @return [Boolean] True if outcome is unknown
      def unknown? = outcome == :unknown

      # Creates a new segment with the given summary text.
      #
      # @param text [String] Summary text to add
      # @return [TrajectorySegment] New segment with summary
      def with_summary(text)
        with(summary: text)
      end

      # @return [Range] Range of step numbers in this segment
      def step_range = start_step..end_step

      # @return [Hash] Hash representation for serialization
      def to_h
        { label:, outcome:, start_step:, end_step:, step_count:, summary: }.compact
      end

      # Enables pattern matching with `in TrajectorySegment[label:, outcome:]`.
      #
      # @param keys [Array, nil] Keys to extract (ignored, returns all)
      # @return [Hash] All fields as a hash
      def deconstruct_keys(_keys) = to_h
    end
  end
end
