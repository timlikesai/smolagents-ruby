module Smolagents
  module Concerns
    module ReActLoop
      # Detects repetitive agent behavior patterns for early loop intervention.
      #
      # Agents can get stuck in loops - calling the same tool with the same
      # arguments, executing the same code, or receiving identical observations.
      # This concern detects these patterns and injects guidance to break the loop.
      #
      # == Detection Patterns
      #
      # The concern checks for three types of repetition:
      #
      # - Tool call repetition: Same tool with same arguments
      # - Code action repetition: Identical code blocks executed
      # - Observation repetition: Similar outputs (using trigram similarity)
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
      # == Events Emitted
      #
      # - {Events::RepetitionDetected} - When a pattern is detected
      #
      # == Integration
      #
      # Include after {ReActLoop} to enable automatic checking:
      #
      #   class MyAgent
      #     include Concerns::ReActLoop
      #     include Concerns::ReActLoop::Repetition
      #   end
      #
      # The concern overrides {Execution#check_and_handle_repetition} to
      # run detection after each step.
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
      # @see Execution For the main loop integration point
      module Repetition
        # Result of repetition detection.
        #
        # @!attribute [r] detected
        #   @return [Boolean] Whether repetition was detected
        # @!attribute [r] pattern
        #   @return [Symbol, nil] Type of repetition (:tool_call, :code_action, :observation)
        # @!attribute [r] count
        #   @return [Integer] Number of repetitions
        # @!attribute [r] guidance
        #   @return [String, nil] Guidance message for the agent
        RepetitionResult = Data.define(:detected, :pattern, :count, :guidance) do
          # @return [Boolean] True if no repetition detected
          def none? = !detected
          # @return [Boolean] True if repetition detected
          def detected? = detected
          # Create a "no repetition" result
          def self.none = new(detected: false, pattern: nil, count: 0, guidance: nil)
          # Create a "repetition detected" result
          def self.detected(pattern:, count:, guidance:) = new(detected: true, pattern:, count:, guidance:)
        end

        # Configuration for repetition detection.
        #
        # @!attribute [r] window_size
        #   @return [Integer] Number of recent steps to check (default: 3)
        # @!attribute [r] similarity_threshold
        #   @return [Float] Threshold for observation similarity (0.0-1.0, default: 0.9)
        # @!attribute [r] enabled
        #   @return [Boolean] Whether detection is enabled
        RepetitionConfig = Data.define(:window_size, :similarity_threshold, :enabled) do
          # Create default configuration
          def self.default = new(window_size: 3, similarity_threshold: 0.9, enabled: true)
        end

        # Check for repetition in recent steps.
        #
        # @param recent_steps [Array<ActionStep>, Enumerable] Steps to check
        # @param config [RepetitionConfig] Detection configuration
        # @return [RepetitionResult] Detection result
        def check_repetition(recent_steps, config: RepetitionConfig.default)
          steps = recent_steps.respond_to?(:to_a) ? recent_steps.to_a : Array(recent_steps)
          return RepetitionResult.none if steps.empty? || !config&.enabled || steps.size < (config&.window_size || 3)

          window = steps.last(config.window_size)
          detect_tool_call_repetition(window) || detect_code_action_repetition(window) ||
            detect_observation_repetition(window, config.similarity_threshold) || RepetitionResult.none
        end

        private

        # Check for repetition in the provided steps and handle if detected.
        # @param steps [Array<ActionStep>] Action steps to check for repetition
        # @param memory [#add_system_message, nil] Optional memory for adding guidance messages
        def check_and_handle_repetition(steps, memory: nil)
          result = check_repetition(steps)
          return if result.none?

          if respond_to?(:emit) && Events.const_defined?(:RepetitionDetected)
            emit(Events::RepetitionDetected.create(pattern: result.pattern, count: result.count,
                                                   guidance: result.guidance))
          end
          return unless result.guidance && memory.respond_to?(:add_system_message)

          memory.add_system_message("[Loop Detection] #{result.guidance}")
        end

        def detect_tool_call_repetition(window)
          sigs = window.filter_map do |step|
            if step.respond_to?(:tool_calls) && step.tool_calls&.any?
              step.tool_calls.map { |tc| [tc.name, normalize_arguments(tc.arguments)] }
            end
          end
          return unless sigs.size >= 2 && sigs.uniq.size == 1

          tool_name = window.last.tool_calls.first.name
          guidance = "You've called '#{tool_name}' #{sigs.size} times with same arguments. " \
                     "Try a different approach."
          RepetitionResult.detected(pattern: :tool_call, count: sigs.size, guidance:)
        end

        def detect_code_action_repetition(window)
          codes = window.filter_map do |s|
            normalize_code(s.code_action) if s.respond_to?(:code_action) && s.code_action
          end
          return unless codes.size >= 2 && codes.uniq.size == 1

          guidance = "You've executed the same code #{codes.size} times. Try a different approach."
          RepetitionResult.detected(pattern: :code_action, count: codes.size, guidance:)
        end

        def detect_observation_repetition(window, threshold)
          obs = window.filter_map do |s|
            s.observations if s.respond_to?(:observations) && s.observations
          end
          all_similar = obs.all? { |o| string_similarity(obs.first.to_s, o.to_s) >= threshold }
          return unless obs.size >= 2 && all_similar

          guidance = "You've received the same result #{obs.size} times. " \
                     "Consider a different tool or inputs."
          RepetitionResult.detected(pattern: :observation, count: obs.size, guidance:)
        end

        def normalize_arguments(args) = args&.transform_values { |v| v.to_s.strip.downcase } || {}
        def normalize_code(code) = code.to_s.gsub(/\s+/, " ").strip

        def string_similarity(first, second)
          return 1.0 if first == second
          return 0.0 if first.empty? || second.empty?

          trigrams_first = trigrams(first)
          trigrams_second = trigrams(second)
          (trigrams_first & trigrams_second).size.to_f / (trigrams_first | trigrams_second).size
        end

        def trigrams(str) = str.length < 3 ? Set.new : Set.new((0..(str.length - 3)).map { |i| str[i, 3] })
      end
    end
  end
end
