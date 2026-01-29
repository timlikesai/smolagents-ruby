# Eval Tools
#
# Standard tool implementations for evaluation tests.
# Deterministic, simple tools for testing model capabilities.

module LiveExperiments
  module Eval
    module Tools
      # Calculator tool for arithmetic
      class Calculator < Smolagents::Tools::Tool
        self.tool_name = "calculator"
        self.description = "Performs arithmetic calculations. Supports +, -, *, / and parentheses."
        self.inputs = {
          expression: { type: "string", description: "Math expression to evaluate (e.g., '15 * 7')" }
        }
        self.output_type = "string"

        def execute(expression:)
          # Sanitize: only allow numbers, operators, parentheses, spaces, decimal points
          sanitized = expression.to_s.gsub(%r{[^0-9+\-*/().\s]}, "")
          result = eval(sanitized) # rubocop:disable Security/Eval -- sandboxed for testing
          "#{result}"
        rescue StandardError => e
          "Error: #{e.message}"
        end
      end

      # Temperature converter
      class TemperatureConverter < Smolagents::Tools::Tool
        self.tool_name = "temperature_converter"
        self.description = "Converts temperature between Fahrenheit and Celsius."
        self.inputs = {
          value: { type: "number", description: "Temperature value to convert" },
          from_unit: { type: "string", description: "Source unit: 'fahrenheit' or 'celsius'" }
        }
        self.output_type = "string"

        def execute(value:, from_unit:)
          case from_unit.to_s.downcase
          when "fahrenheit", "f"
            celsius = ((value.to_f - 32) * 5 / 9).round(2)
            "#{value}°F = #{celsius}°C"
          when "celsius", "c"
            fahrenheit = ((value.to_f * 9 / 5) + 32).round(2)
            "#{value}°C = #{fahrenheit}°F"
          else
            "Error: Unknown unit '#{from_unit}'. Use 'fahrenheit' or 'celsius'."
          end
        end
      end

      # Word counter
      class WordCounter < Smolagents::Tools::Tool
        self.tool_name = "word_counter"
        self.description = "Counts the number of words in a text string."
        self.inputs = {
          text: { type: "string", description: "Text to count words in" }
        }
        self.output_type = "string"

        def execute(text:)
          count = text.to_s.split(/\s+/).reject(&:empty?).size
          "Word count: #{count}"
        end
      end

      # Standard tool set for evaluation
      def self.standard_set
        {
          "calculator" => Calculator.new,
          "temperature_converter" => TemperatureConverter.new,
          "word_counter" => WordCounter.new
        }
      end
    end
  end
end
