module Smolagents
  module Interactive
    module Progress
      # Tracks and displays token usage during agent execution.
      #
      # Shows cumulative token counts with cost estimate:
      #   Tokens: 1,234 in / 567 out ($0.02)
      #
      # @example Usage
      #   counter = TokenCounter.new
      #   counter.add(input: 500, output: 100)
      #   counter.display  #=> "Tokens: 500 in / 100 out"
      #
      class TokenCounter
        # Approximate costs per 1K tokens (varies by model)
        DEFAULT_INPUT_COST = 0.0001
        DEFAULT_OUTPUT_COST = 0.0002

        def initialize(output: $stdout, input_cost: DEFAULT_INPUT_COST, output_cost: DEFAULT_OUTPUT_COST)
          @output = output
          @input_cost = input_cost
          @output_cost = output_cost
          @input_tokens = 0
          @output_tokens = 0
        end

        attr_reader :input_tokens, :output_tokens

        def add(input: 0, output: 0)
          @input_tokens += input
          @output_tokens += output
        end

        def total_tokens = @input_tokens + @output_tokens

        def estimated_cost
          (@input_tokens / 1000.0 * @input_cost) + (@output_tokens / 1000.0 * @output_cost)
        end

        def display
          return unless tty? && total_tokens.positive?

          @output.puts summary_line
        end

        def summary_line
          tokens = "#{dim("Tokens:")} #{format_number(@input_tokens)} in / #{format_number(@output_tokens)} out"
          cost = estimated_cost
          cost_str = cost > 0.001 ? " #{dim("($#{format("%.2f", cost)})")}" : ""
          "#{tokens}#{cost_str}"
        end

        def reset
          @input_tokens = 0
          @output_tokens = 0
        end

        private

        def format_number(num)
          num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
        end

        def tty? = @output.respond_to?(:tty?) && @output.tty?
        def dim(text) = Colors.wrap(text, Colors::DIM)
      end
    end
  end
end
