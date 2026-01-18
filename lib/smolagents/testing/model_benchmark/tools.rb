module Smolagents
  module Testing
    class ModelBenchmark
      # Tool builders for benchmark tests.
      module BenchmarkTools
        private

        def build_tools(tool_symbols)
          tool_symbols.map { |sym| tool_for_symbol(sym) }
        end

        def tool_for_symbol(sym)
          case sym
          when :calculator then calculator_tool
          when :search then search_tool
          else raise ArgumentError, "Unknown tool: #{sym}"
          end
        end

        def calculator_tool
          @calculator_tool ||= Tools.define_tool(
            "calculate",
            description: "Evaluate a mathematical expression. Example: calculate(expression: '2 + 2')",
            inputs: { "expression" => { "type" => "string", "description" => "Math expression to evaluate" } },
            output_type: "number"
          ) { |expression:| safe_eval(expression) }
        end

        def safe_eval(expression)
          cleaned = expression.to_s.gsub(%r{[^0-9+\-*/().\s]}, "")
          eval(cleaned).to_f # rubocop:disable Security/Eval
        end

        def search_tool
          @search_tool ||= Tools::SearxngSearchTool.new(
            instance_url: ENV.fetch("SEARXNG_URL", "https://searxng.reverse-bull.ts.net")
          )
        end
      end
    end
  end
end
