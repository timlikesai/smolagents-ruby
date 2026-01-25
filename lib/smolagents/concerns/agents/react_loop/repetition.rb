module Smolagents
  module Concerns
    module ReActLoop
      # Detects repetitive agent behavior patterns for early loop intervention.
      #
      # Agents can get stuck in loops - calling the same tool with the same
      # arguments, executing the same code, or receiving identical observations.
      # This concern detects these patterns and injects guidance to break the loop.
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

        # Message templates for breaking repetition loops.
        GUIDANCE_TEMPLATES = {
          tool_call: "You've called '%<tool>s' %<count>d times with same arguments. " \
                     "Try a different approach.",
          code_action: "You've executed the same code %<count>d times. " \
                       "Try a different approach.",
          observation: "You've received the same result %<count>d times. " \
                       "Consider a different tool or inputs."
        }.freeze

        def self.provided_methods
          {
            check_repetition: "Check for repetitive patterns in recent steps",
            string_similarity: "Calculate Jaccard similarity between two strings using trigrams",
            trigrams: "Extract character trigrams from a string as a Set"
          }
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

        # === Similarity Calculation ===

        def string_similarity(first, second) = Utilities::Similarity.string(first, second)

        def trigrams(str) = Utilities::Similarity.trigrams(str)

        # === Guidance Generation ===

        def generate_tool_guidance(tool_name, count)
          format(GUIDANCE_TEMPLATES[:tool_call], tool: tool_name, count:)
        end

        def generate_code_guidance(count)
          format(GUIDANCE_TEMPLATES[:code_action], count:)
        end

        def generate_observation_guidance(count)
          format(GUIDANCE_TEMPLATES[:observation], count:)
        end

        # === Detection Logic ===

        def detect_tool_call_repetition(window)
          sigs = window.filter_map { |s| extract_tool_signature(s) }
          return unless sigs.size >= 2 && sigs.uniq.size == 1

          tool_name = window.last.tool_calls.first.name
          RepetitionResult.detected(
            pattern: :tool_call, count: sigs.size,
            guidance: generate_tool_guidance(tool_name, sigs.size)
          )
        end

        def extract_tool_signature(step)
          return unless step.respond_to?(:tool_calls) && step.tool_calls&.any?

          step.tool_calls.map { |tc| [tc.name, normalize_arguments(tc.arguments)] }
        end

        def detect_code_action_repetition(window)
          codes = window.filter_map do |s|
            normalize_code(s.code_action) if s.respond_to?(:code_action) && s.code_action
          end
          return unless codes.size >= 2 && codes.uniq.size == 1

          RepetitionResult.detected(
            pattern: :code_action, count: codes.size,
            guidance: generate_code_guidance(codes.size)
          )
        end

        def detect_observation_repetition(window, threshold)
          obs = window.filter_map do |s|
            s.observations if s.respond_to?(:observations) && s.observations
          end
          return unless obs.size >= 2

          all_similar = obs.all? { |o| string_similarity(obs.first.to_s, o.to_s) >= threshold }
          return unless all_similar

          RepetitionResult.detected(
            pattern: :observation, count: obs.size,
            guidance: generate_observation_guidance(obs.size)
          )
        end

        def normalize_arguments(args) = args&.transform_values { |v| v.to_s.strip.downcase } || {}
        def normalize_code(code) = code.to_s.gsub(/\s+/, " ").strip

        # === Repetition Handling ===

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
