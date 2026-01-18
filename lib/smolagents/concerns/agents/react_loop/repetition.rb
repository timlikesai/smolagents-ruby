require_relative "repetition/similarity"
require_relative "repetition/guidance"
require_relative "repetition/detectors"

module Smolagents
  module Concerns
    module ReActLoop
      # Detects repetitive agent behavior patterns for early loop intervention.
      #
      # Agents can get stuck in loops - calling the same tool with the same
      # arguments, executing the same code, or receiving identical observations.
      # This concern detects these patterns and injects guidance to break the loop.
      #
      # == Sub-modules
      #
      # - {Repetition::Similarity} - Trigram-based string similarity
      # - {Repetition::Guidance} - Message templates for breaking loops
      # - {Repetition::Detectors} - Pattern detection logic
      #
      # == Configuration
      #
      # Use {RepetitionConfig} to tune detection:
      #
      #   config = RepetitionConfig.new(
      #     window_size: 3,           # Steps to check
      #     similarity_threshold: 0.9, # For observation matching
      #     enabled: true
      #   )
      #
      # @example Manual repetition checking
      #   result = check_repetition(memory.action_steps.last(3))
      #   if result.detected?
      #     puts "Pattern: #{result.pattern}, Count: #{result.count}"
      #     puts result.guidance
      #   end
      #
      # @see RepetitionResult For detection results
      # @see RepetitionConfig For configuration options
      module Repetition
        def self.included(base)
          base.include(Similarity)
          base.include(Guidance)
          base.include(Detectors)
        end

        # Result of repetition detection.
        RepetitionResult = Data.define(:detected, :pattern, :count, :guidance) do
          def none? = !detected
          def detected? = detected
          def self.none = new(detected: false, pattern: nil, count: 0, guidance: nil)
          def self.detected(pattern:, count:, guidance:) = new(detected: true, pattern:, count:, guidance:)
        end

        # Configuration for repetition detection.
        RepetitionConfig = Data.define(:window_size, :similarity_threshold, :enabled) do
          def self.default = new(window_size: 3, similarity_threshold: 0.9, enabled: true)
        end

        # Check for repetition in recent steps.
        #
        # @param recent_steps [Array<ActionStep>, Enumerable] Steps to check
        # @param config [RepetitionConfig] Detection configuration
        # @return [RepetitionResult] Detection result
        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def check_repetition(recent_steps, config: RepetitionConfig.default)
          steps = recent_steps.respond_to?(:to_a) ? recent_steps.to_a : Array(recent_steps)
          return RepetitionResult.none if steps.empty? || !config&.enabled
          return RepetitionResult.none if steps.size < (config&.window_size || 3)

          window = steps.last(config.window_size)
          detect_tool_call_repetition(window) ||
            detect_code_action_repetition(window) ||
            detect_observation_repetition(window, config.similarity_threshold) ||
            RepetitionResult.none
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        private

        # Check for repetition and handle if detected.
        #
        # @param steps [Array<ActionStep>] Action steps to check
        # @param memory [#add_system_message, nil] Optional memory for guidance
        def check_and_handle_repetition(steps, memory: nil)
          result = check_repetition(steps)
          return if result.none?

          if respond_to?(:emit) && Events.const_defined?(:RepetitionDetected)
            emit(Events::RepetitionDetected.create(
                   pattern: result.pattern, count: result.count, guidance: result.guidance
                 ))
          end
          return unless result.guidance && memory.respond_to?(:add_system_message)

          memory.add_system_message("[Loop Detection] #{result.guidance}")
        end
      end
    end
  end
end
