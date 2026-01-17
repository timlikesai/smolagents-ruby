module Smolagents
  module Concerns
    module ReActLoop
      # Detects when an agent is stuck in a repetitive loop before hitting max_steps.
      #
      # Research shows that "consecutive identical actions leading to same observation"
      # is a reliable signal to intervene. This concern catches loops 2-3 steps earlier
      # than max_steps, saving tokens and enabling recovery.
      #
      # @see https://arxiv.org/abs/2303.11366 Reflexion paper on loop detection
      # @see https://metadesignsolutions.com/using-the-react-pattern-in-ai-agents ReAct best practices
      #
      # @example Including in an agent
      #   class MyAgent
      #     include Concerns::ReActLoop::RepetitionDetection
      #
      #     def run_step(task, ctx)
      #       step = execute_step(task, ctx)
      #       if (warning = check_repetition(step))
      #         inject_guidance(warning)
      #       end
      #       step
      #     end
      #   end
      module RepetitionDetection
        # Result of repetition detection.
        # @!attribute [r] detected
        #   @return [Boolean] Whether repetition was detected
        # @!attribute [r] pattern
        #   @return [Symbol, nil] Type of repetition (:tool_call, :code_action, :observation)
        # @!attribute [r] count
        #   @return [Integer] Number of repetitions detected
        # @!attribute [r] guidance
        #   @return [String, nil] Suggested guidance to inject
        RepetitionResult = Data.define(:detected, :pattern, :count, :guidance) do
          # Whether no repetition was detected.
          # @return [Boolean]
          def none? = !detected

          # Whether repetition was detected.
          # @return [Boolean]
          def detected? = detected

          # Factory for no repetition detected.
          # @return [RepetitionResult]
          def self.none
            new(detected: false, pattern: nil, count: 0, guidance: nil)
          end

          # Factory for detected repetition.
          # @param pattern [Symbol] Type of repetition
          # @param count [Integer] Number of repetitions
          # @param guidance [String] Guidance message
          # @return [RepetitionResult]
          def self.detected(pattern:, count:, guidance:)
            new(detected: true, pattern:, count:, guidance:)
          end
        end

        # Configuration for repetition detection.
        # @!attribute [r] window_size
        #   @return [Integer] Number of recent steps to examine (default: 3)
        # @!attribute [r] similarity_threshold
        #   @return [Float] Threshold for observation similarity (0.0-1.0, default: 0.9)
        # @!attribute [r] enabled
        #   @return [Boolean] Whether detection is enabled (default: true)
        RepetitionConfig = Data.define(:window_size, :similarity_threshold, :enabled) do
          # Default configuration.
          # @return [RepetitionConfig]
          def self.default
            new(window_size: 3, similarity_threshold: 0.9, enabled: true)
          end
        end

        # Checks for repetitive patterns in recent steps.
        #
        # Detects three types of repetition:
        # 1. Same tool called with identical arguments
        # 2. Same code action executed repeatedly
        # 3. Same or very similar observations returned
        #
        # @param recent_steps [Array<ActionStep>] Recent action steps to analyze
        # @param config [RepetitionConfig] Detection configuration
        # @return [RepetitionResult] Detection result with guidance if applicable
        #
        # @example
        #   result = check_repetition(memory.action_steps.last(3))
        #   if result.detected?
        #     inject_guidance(result.guidance)
        #   end
        def check_repetition(recent_steps, config: Smolagents::Concerns::ReActLoop::RepetitionDetection::RepetitionConfig.default)
          # Convert to array to handle Enumerator::Lazy
          steps_array = recent_steps.respond_to?(:to_a) ? recent_steps.to_a : Array(recent_steps)
          return Smolagents::Concerns::ReActLoop::RepetitionDetection::RepetitionResult.none if steps_array.empty?
          return Smolagents::Concerns::ReActLoop::RepetitionDetection::RepetitionResult.none unless config&.enabled
          if steps_array.size < (config&.window_size || 3)
            return Smolagents::Concerns::ReActLoop::RepetitionDetection::RepetitionResult.none
          end

          recent_steps = steps_array

          window = recent_steps.last(config.window_size)

          # Check for identical tool calls
          if (result = detect_tool_call_repetition(window))
            return result
          end

          # Check for identical code actions
          if (result = detect_code_action_repetition(window))
            return result
          end

          # Check for similar observations
          if (result = detect_observation_repetition(window, config.similarity_threshold))
            return result
          end

          Smolagents::Concerns::ReActLoop::RepetitionDetection::RepetitionResult.none
        end

        # Checks if the agent appears stuck based on recent history.
        #
        # @param memory [AgentMemory] Agent's memory containing step history
        # @param config [RepetitionConfig] Detection configuration
        # @return [RepetitionResult] Detection result
        def repetition_detected?(memory, config: Smolagents::Concerns::ReActLoop::RepetitionDetection::RepetitionConfig.default)
          unless memory.respond_to?(:action_steps)
            return Smolagents::Concerns::ReActLoop::RepetitionDetection::RepetitionResult.none
          end

          check_repetition(memory.action_steps, config:)
        end

        private

        # Detects repeated tool calls with same arguments.
        # @param window [Array<ActionStep>] Steps to check
        # @return [RepetitionResult, nil] Result if repetition found
        def detect_tool_call_repetition(window)
          # Extract tool calls from each step
          tool_signatures = window.filter_map do |step|
            next unless step.respond_to?(:tool_calls) && step.tool_calls&.any?

            step.tool_calls.map { |tc| [tc.name, normalize_arguments(tc.arguments)] }
          end

          return nil if tool_signatures.empty?

          # Check if all tool call signatures are identical
          return unless tool_signatures.uniq.size == 1 && tool_signatures.size >= 2

          tool_name = window.last.tool_calls.first.name
          Smolagents::Concerns::ReActLoop::RepetitionDetection::RepetitionResult.detected(
            pattern: :tool_call,
            count: tool_signatures.size,
            guidance: build_tool_call_guidance(tool_name, tool_signatures.size)
          )
        end

        # Detects repeated code actions.
        # @param window [Array<ActionStep>] Steps to check
        # @return [RepetitionResult, nil] Result if repetition found
        def detect_code_action_repetition(window)
          code_actions = window.filter_map do |step|
            step.code_action if step.respond_to?(:code_action) && step.code_action
          end

          return nil if code_actions.size < 2

          # Normalize code for comparison (strip whitespace variations)
          normalized = code_actions.map { |c| normalize_code(c) }

          return unless normalized.uniq.size == 1

          Smolagents::Concerns::ReActLoop::RepetitionDetection::RepetitionResult.detected(
            pattern: :code_action,
            count: normalized.size,
            guidance: build_code_action_guidance(normalized.size)
          )
        end

        # Detects similar observations being returned repeatedly.
        # @param window [Array<ActionStep>] Steps to check
        # @param threshold [Float] Similarity threshold (0.0-1.0)
        # @return [RepetitionResult, nil] Result if repetition found
        def detect_observation_repetition(window, threshold)
          observations = window.filter_map do |step|
            step.observations if step.respond_to?(:observations) && step.observations
          end

          return nil if observations.size < 2

          # Check if all observations are similar
          first = observations.first.to_s
          all_similar = observations.all? { |obs| string_similarity(first, obs.to_s) >= threshold }

          return unless all_similar

          Smolagents::Concerns::ReActLoop::RepetitionDetection::RepetitionResult.detected(
            pattern: :observation,
            count: observations.size,
            guidance: build_observation_guidance(observations.size)
          )
        end

        # Normalizes arguments for comparison.
        # @param args [Hash, nil] Tool arguments
        # @return [Hash] Normalized arguments
        def normalize_arguments(args)
          return {} if args.nil?

          args.transform_values { |v| v.to_s.strip.downcase }
        end

        # Normalizes code for comparison.
        # @param code [String] Ruby code
        # @return [String] Normalized code
        def normalize_code(code)
          code.to_s.gsub(/\s+/, " ").strip
        end

        # Simple string similarity using Jaccard index on character trigrams.
        # @param a [String] First string
        # @param b [String] Second string
        # @return [Float] Similarity score (0.0-1.0)
        def string_similarity(a, b)
          return 1.0 if a == b
          return 0.0 if a.empty? || b.empty?

          trigrams_a = trigrams(a)
          trigrams_b = trigrams(b)

          intersection = (trigrams_a & trigrams_b).size
          union = (trigrams_a | trigrams_b).size

          union.zero? ? 0.0 : intersection.to_f / union
        end

        # Extracts character trigrams from a string.
        # @param str [String] Input string
        # @return [Set<String>] Set of trigrams
        def trigrams(str)
          return Set.new if str.length < 3

          Set.new((0..(str.length - 3)).map { |i| str[i, 3] })
        end

        # Builds guidance for repeated tool calls.
        # @param tool_name [String] Name of the repeated tool
        # @param count [Integer] Number of repetitions
        # @return [String] Guidance message
        def build_tool_call_guidance(tool_name, count)
          <<~GUIDANCE.strip
            You've called '#{tool_name}' #{count} times with the same arguments.
            This suggests you're stuck in a loop. Try one of:
            1. Use a different approach or tool
            2. Modify your arguments
            3. Call final_answer with what you have so far
          GUIDANCE
        end

        # Builds guidance for repeated code actions.
        # @param count [Integer] Number of repetitions
        # @return [String] Guidance message
        def build_code_action_guidance(count)
          <<~GUIDANCE.strip
            You've executed the same code #{count} times in a row.
            The approach isn't working. Try:
            1. A different algorithm or method
            2. Breaking the problem into smaller steps
            3. Calling final_answer with partial progress
          GUIDANCE
        end

        # Builds guidance for repeated observations.
        # @param count [Integer] Number of repetitions
        # @return [String] Guidance message
        def build_observation_guidance(count)
          <<~GUIDANCE.strip
            You've received the same result #{count} times.
            You may be stuck. Consider:
            1. Using different inputs or parameters
            2. Trying a different tool
            3. Concluding with final_answer
          GUIDANCE
        end
      end
    end
  end
end
