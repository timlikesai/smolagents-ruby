module Smolagents
  module Concerns
    module ReActLoop
      module Repetition
        # Message generation for breaking repetition loops.
        #
        # Provides templates and generation methods for creating guidance
        # messages that help agents escape repetitive behavior patterns.
        module Guidance
          # === Self-Documentation ===
          def self.provided_methods
            {
              generate_tool_guidance: "Creates guidance for tool call repetition",
              generate_code_guidance: "Creates guidance for code action repetition",
              generate_observation_guidance: "Creates guidance for observation repetition"
            }
          end

          TEMPLATES = {
            tool_call: "You've called '%<tool>s' %<count>d times with same arguments. " \
                       "Try a different approach.",
            code_action: "You've executed the same code %<count>d times. " \
                         "Try a different approach.",
            observation: "You've received the same result %<count>d times. " \
                         "Consider a different tool or inputs."
          }.freeze

          private

          # Generate guidance for tool call repetition.
          #
          # @param tool_name [String] Name of the repeated tool
          # @param count [Integer] Number of repetitions
          # @return [String] Guidance message
          def generate_tool_guidance(tool_name, count)
            format(TEMPLATES[:tool_call], tool: tool_name, count:)
          end

          # Generate guidance for code action repetition.
          #
          # @param count [Integer] Number of repetitions
          # @return [String] Guidance message
          def generate_code_guidance(count)
            format(TEMPLATES[:code_action], count:)
          end

          # Generate guidance for observation repetition.
          #
          # @param count [Integer] Number of repetitions
          # @return [String] Guidance message
          def generate_observation_guidance(count)
            format(TEMPLATES[:observation], count:)
          end
        end
      end
    end
  end
end
