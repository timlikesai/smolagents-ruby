require "json"

module Smolagents
  module Utilities
    module PatternMatching
      # Extracts JSON from LLM responses.
      # Handles json code blocks and inline JSON objects.
      module JsonExtraction
        class << self
          def extract(text)
            json_str = from_code_block(text) || from_inline(text)
            json_str && JSON.parse(json_str)
          rescue JSON::ParserError
            nil
          end

          private

          def from_code_block(text)
            text.match(/```json\n(.+?)```/m)&.[](1)
          end

          def from_inline(text)
            text.match(/\{.+\}/m)&.[](0)
          end
        end
      end
    end
  end
end
