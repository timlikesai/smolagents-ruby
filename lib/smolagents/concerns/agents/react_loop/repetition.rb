module Smolagents
  module Concerns
    module ReActLoop
      # Detects repetitive agent behavior (tool calls, code, observations)
      # and injects specific guidance naming what was repeated and suggesting
      # concrete alternatives based on available tools.
      #
      # @see Types::RepetitionResult For detection results
      # @see Types::RepetitionConfig For configuration options
      module Repetition
        # Lazily resolve types to avoid load-order dependencies
        def self.result_type = Smolagents::Types::RepetitionResult
        def self.config_type = Smolagents::Types::RepetitionConfig

        # Message templates for breaking repetition loops.
        GUIDANCE_TEMPLATES = {
          tool_call: "You've called %<tool>s(%<args>s) %<count>d times with similar results. %<alternatives>s",
          code_action: "You've executed the same code %<count>d times: %<code_preview>s. %<suggestion>s",
          observation: "You've received the same result %<count>d times. %<alternatives>s"
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
        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity -- multi-pattern detection requires branching
        def check_repetition(recent_steps, config: Repetition.config_type.default)
          steps = recent_steps.respond_to?(:to_a) ? recent_steps.to_a : Array(recent_steps)
          return Repetition.result_type.none if steps.empty? || !config&.enabled
          return Repetition.result_type.none if steps.size < (config&.window_size || 3)

          window = steps.last(config.window_size)
          detect_tool_call_repetition(window) ||
            detect_code_action_repetition(window) ||
            detect_observation_repetition(window, config.similarity_threshold) ||
            Repetition.result_type.none
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        private

        # === Similarity Calculation ===

        def string_similarity(first, second) = Utilities::Similarity.string(first, second)

        def trigrams(str) = Utilities::Similarity.trigrams(str)

        # === Guidance Generation ===

        def generate_tool_guidance(tool_name, count, args: {})
          args_str = args.map { |k, v| "#{k}: #{v.inspect}" }.join(", ").then { it[0, 60] }
          alts = repetition_alternatives(tool_name)
          format(GUIDANCE_TEMPLATES[:tool_call], tool: tool_name, args: args_str, count:, alternatives: alts)
        end

        def generate_code_guidance(count, code_preview: "...")
          preview = code_preview[0, 50]
          format(GUIDANCE_TEMPLATES[:code_action], count:, code_preview: preview, suggestion: code_alternative)
        end

        def generate_observation_guidance(count)
          format(GUIDANCE_TEMPLATES[:observation], count:, alternatives: observation_alternative)
        end

        def repetition_alternatives(failed_tool)
          others = respond_to?(:tool_names) ? (tool_names - [failed_tool]).first(3) : []
          others.any? ? "Try a different tool: #{others.join(", ")}" : "Try different arguments or call final_answer."
        end

        def code_alternative = "Modify your approach or try a different tool."
        def observation_alternative = "Try different arguments, a different tool, or call final_answer."

        # === Detection Logic ===

        def detect_tool_call_repetition(window)
          sigs = window.filter_map { |s| extract_tool_signature(s) }
          return unless sigs.size >= 2 && sigs.uniq.size == 1

          tc = window.last.tool_calls.first
          Repetition.result_type.detected(
            pattern: :tool_call, count: sigs.size,
            guidance: generate_tool_guidance(tc.name, sigs.size, args: tc.arguments || {})
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

          Repetition.result_type.detected(
            pattern: :code_action, count: codes.size,
            guidance: generate_code_guidance(codes.size, code_preview: codes.first)
          )
        end

        # rubocop:disable Metrics/AbcSize -- slightly over threshold, readable as-is
        def detect_observation_repetition(window, threshold)
          obs = window.filter_map do |s|
            s.observations if s.respond_to?(:observations) && s.observations
          end
          return unless obs.size >= 2

          all_similar = obs.all? { |o| string_similarity(obs.first.to_s, o.to_s) >= threshold }
          return unless all_similar

          Repetition.result_type.detected(
            pattern: :observation, count: obs.size,
            guidance: generate_observation_guidance(obs.size)
          )
        end
        # rubocop:enable Metrics/AbcSize

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
