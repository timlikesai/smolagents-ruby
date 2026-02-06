require_relative "return_type_hints"

module Smolagents
  module Utilities
    module Prompts
      module Agent
        # Tool formatting helpers for agent prompts.
        #
        # ONE format for all models — signatures, return types, examples.
        # final_answer gets special emphasis (>>>) since models often forget it.
        module ToolFormatting
          include ReturnTypeHints

          # Format a tool with signature, return type, description, and example.
          def format_tool(tool)
            return "- #{tool}" if tool.is_a?(String)

            final_answer?(tool) ? format_final_answer(tool) : format_standard_tool(tool)
          end

          def build_signature(tool)
            inputs = tool.inputs || {}
            params = inputs.map { |n, spec| format_param_signature(n, spec) }
            params.empty? ? "#{tool.name}()" : "#{tool.name}(#{params.join(", ")})"
          end

          def format_param_signature(name, spec)
            type = spec[:type] || spec["type"]
            type_str = spec[:nullable] || spec["nullable"] ? "#{type}?" : type.to_s
            "#{name}: #{type_str}"
          end

          def build_example(tool)
            inputs = tool.inputs || {}
            args = inputs.map { |n, spec| format_example_arg(n, spec) }
            call = args.empty? ? "#{tool.name}()" : "#{tool.name}(#{args.join(", ")})"
            "result = #{call}#{build_return_comment(tool)}"
          end

          def build_return_comment(tool)
            return "" unless tool.respond_to?(:output_type) && tool.output_type

            "  # Returns #{tool.output_type}"
          end

          def format_example_arg(name, spec)
            type = spec[:type] || spec["type"]
            desc = spec[:description] || spec["description"] || ""
            "#{name}: #{Templates.example_for_type(type, desc, name.to_s).inspect}"
          end

          private

          def final_answer?(tool) = tool.respond_to?(:name) && tool.name.to_s == "final_answer"

          def format_final_answer(tool)
            sig = build_signature(tool)
            ">>> #{sig} — #{tool.description}\n  Example: final_answer(answer: \"Your summarized result\")"
          end

          def format_standard_tool(tool)
            hint = build_return_hint(tool)
            "- #{build_signature(tool)}#{hint} — #{tool.description}\n  Example: #{build_example(tool)}"
          end
        end
      end
    end
  end
end
