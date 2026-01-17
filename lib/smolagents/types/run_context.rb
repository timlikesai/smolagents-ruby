module Smolagents
  module Types
    # Immutable context tracking a run's progress.
    #
    # Maintains the current step number, cumulative token usage, and timing
    # information throughout an agent run. Enables progress tracking and
    # limit checking (max steps, max tokens).
    #
    # @!attribute [r] step_number
    #   @return [Integer] Current step number (1-based)
    # @!attribute [r] total_tokens
    #   @return [TokenUsage] Accumulated token usage
    # @!attribute [r] timing
    #   @return [Timing] Start and end times for the run
    #
    # @example Tracking run progress
    #   context = Smolagents::Types::RunContext.start
    #   context.step_number  # => 1
    #   context = context.advance
    #   context.step_number  # => 2
    #
    # @see ExecutionOutcome For run result tracking
    # @see Agents#run Uses this to track progress
    RunContext = Data.define(:step_number, :total_tokens, :timing) do
      # Creates a RunContext starting at step 1 with zero tokens.
      #
      # @return [RunContext] Context ready for execution
      def self.start = new(step_number: 1, total_tokens: TokenUsage.zero, timing: Timing.start_now)

      # Advances to the next step.
      #
      # @return [RunContext] New context with incremented step_number
      def advance = with(step_number: step_number + 1)

      # Adds token usage to the running total.
      #
      # @param usage [TokenUsage, nil] Tokens to add
      # @return [RunContext] New context with updated total_tokens (unchanged if usage is nil)
      def add_tokens(usage) = usage ? with(total_tokens: total_tokens + usage) : self

      # Marks the run as finished.
      #
      # @return [RunContext] New context with timing stopped
      def finish = with(timing: timing.stop)

      # Checks if step count exceeds maximum.
      #
      # @param max_steps [Integer] Maximum allowed steps
      # @return [Boolean] True if current step exceeds max
      def exceeded?(max_steps) = step_number > max_steps

      # Calculates how many steps have completed (not including current).
      #
      # @return [Integer] Number of completed steps
      def steps_completed = step_number - 1

      # Enables pattern matching with `in RunContext[step_number:, total_tokens:]`.
      #
      # @param keys [Array, nil] Keys to extract (ignored, returns all)
      # @return [Hash] All fields as a hash
      def deconstruct_keys(_keys) = { step_number:, total_tokens:, timing:, steps_completed: }
    end
  end
end
