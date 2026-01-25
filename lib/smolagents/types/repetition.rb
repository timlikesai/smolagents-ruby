module Smolagents
  module Types
    # Result of repetition detection.
    #
    # Returned by repetition checking to indicate whether a repetitive pattern
    # was detected in agent behavior.
    #
    # @example No repetition detected
    #   result = RepetitionResult.none
    #   result.none?      # => true
    #   result.detected?  # => false
    #
    # @example Repetition detected
    #   result = RepetitionResult.detected(
    #     pattern: :tool_call,
    #     count: 3,
    #     guidance: "Try a different approach"
    #   )
    #   result.detected?  # => true
    #   result.pattern    # => :tool_call
    #
    # @see Concerns::ReActLoop::Repetition For detection logic
    RepetitionResult = Data.define(:detected, :pattern, :count, :guidance) do
      # @return [Boolean] true if no repetition detected
      def none? = !detected

      # @return [Boolean] true if repetition was detected
      def detected? = detected

      # Creates a result indicating no repetition.
      # @return [RepetitionResult]
      def self.none = new(detected: false, pattern: nil, count: 0, guidance: nil)

      # Creates a result indicating repetition was detected.
      # @param pattern [Symbol] Type of repetition (:tool_call, :code_action, :observation)
      # @param count [Integer] Number of repetitions detected
      # @param guidance [String] Suggested guidance to break the loop
      # @return [RepetitionResult]
      def self.detected(pattern:, count:, guidance:) = new(detected: true, pattern:, count:, guidance:)
    end

    # Configuration for repetition detection.
    #
    # Controls how the repetition detector identifies patterns in agent behavior.
    #
    # @example Default configuration
    #   config = RepetitionConfig.default
    #   config.window_size          # => 3
    #   config.similarity_threshold # => 0.9
    #   config.enabled              # => true
    #
    # @example Custom configuration
    #   config = RepetitionConfig.new(
    #     window_size: 5,
    #     similarity_threshold: 0.85,
    #     enabled: true
    #   )
    #
    # @see Concerns::ReActLoop::Repetition For detection logic
    RepetitionConfig = Data.define(:window_size, :similarity_threshold, :enabled) do
      # Creates the default repetition detection configuration.
      # @return [RepetitionConfig]
      def self.default = new(window_size: 3, similarity_threshold: 0.9, enabled: true)
    end
  end
end
