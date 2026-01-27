module Smolagents
  module Utilities
    module Prompts
      module Agent
        # Tool formatting helpers for agent prompts.
        # Extracted to keep Agent module under 100 lines.
        module ToolFormatting
          # Format a tool with full schema (signatures, types, examples).
          # ~100-200 tokens per tool.
          def format_tool(tool)
            return "- #{tool}" if tool.is_a?(String)

            signature = build_signature(tool)
            example = build_example(tool)
            return_hint = build_return_hint(tool)
            "- #{signature}#{return_hint} - #{tool.description}\n  Example: #{example}"
          end

          # Format a tool with condensed summary for progressive disclosure.
          # ~20 tokens per tool. Use help(:tool_name) for full details.
          def format_tool_summary(tool)
            return "- #{tool}" if tool.is_a?(String)

            name = tool.name
            # Take first sentence of description, max 50 chars
            desc = tool.description.to_s.split(/[.!?]/).first.to_s.strip
            desc = "#{desc[0, 47]}..." if desc.length > 50
            "- #{name}: #{desc}"
          end

          def build_return_hint(tool)
            return "" unless tool.respond_to?(:output_type) && tool.output_type

            detailed = detailed_type_hint(tool)
            detailed || " -> #{tool.output_type.capitalize}"
          end

          def detailed_type_hint(tool)
            return nil unless tool.respond_to?(:output_schema) && tool.output_schema

            schema = tool.output_schema
            return format_json_schema_hint(schema) if schema[:type] || schema["type"]

            # Simple property-based schema (keys are property names)
            format_property_hint(tool.output_type, schema)
          end

          def format_json_schema_hint(schema)
            type = schema[:type] || schema["type"]
            case type
            when "array" then format_array_hint(schema)
            when "object" then format_object_hint(schema)
            else " -> #{type.capitalize}"
            end
          end

          def format_array_hint(schema)
            items = get_value(schema, :items)
            return " -> Array" unless items

            format_array_item_hint(items)
          end

          def format_array_item_hint(items)
            item_type = get_value(items, :type)
            props = item_type == "object" ? get_value(items, :properties) : nil
            props ? " -> Array<{#{keys_preview(props)}}>" : " -> Array<#{item_type&.capitalize || "Any"}>"
          end

          def format_object_hint(schema)
            props = get_value(schema, :properties)
            return " -> Object" unless props

            " -> Object{#{keys_preview(props)}}"
          end

          def format_property_hint(output_type, schema)
            " -> #{output_type.capitalize}{#{keys_preview(schema)}}"
          end

          def get_value(hash, key) = hash[key] || hash[key.to_s]

          def keys_preview(props)
            keys = props.keys.take(3).join(", ")
            props.size > 3 ? "#{keys}, ..." : keys
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
