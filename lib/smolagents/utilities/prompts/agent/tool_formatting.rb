module Smolagents
  module Utilities
    module Prompts
      module Agent
        # Tool formatting helpers for agent prompts.
        # Extracted to keep Agent module under 100 lines.
        module ToolFormatting
          def format_tool(tool)
            return "- #{tool}" if tool.is_a?(String)

            signature = build_signature(tool)
            example = build_example(tool)
            return_hint = build_return_hint(tool)
            "- #{signature}#{return_hint} - #{tool.description}\n  Example: #{example}"
          end

          def build_return_hint(tool)
            return "" unless tool.respond_to?(:output_type) && tool.output_type

            " -> #{tool.output_type.capitalize}"
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
            return_comment = build_return_comment(tool)
            "result = #{call}#{return_comment}"
          end

          def build_return_comment(tool)
            return "" unless tool.respond_to?(:output_type) && tool.output_type

            "  # Returns #{tool.output_type} directly"
          end

          def format_example_arg(name, spec)
            type = spec[:type] || spec["type"]
            desc = spec[:description] || spec["description"] || ""
            "#{name}: #{Templates.example_for_type(type, desc, name.to_s).inspect}"
          end
        end
      end
    end
  end
end
