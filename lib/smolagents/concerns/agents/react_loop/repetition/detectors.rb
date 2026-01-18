module Smolagents
  module Concerns
    module ReActLoop
      module Repetition
        # Detection logic for tool calls, code actions, and observations.
        module Detectors
          def self.provided_methods
            {
              detect_tool_call_repetition: "Detects repeated tool calls with same arguments",
              detect_code_action_repetition: "Detects repeated code actions",
              detect_observation_repetition: "Detects similar observations via trigram matching"
            }
          end

          private

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
        end
      end
    end
  end
end
