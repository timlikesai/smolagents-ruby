module Smolagents
  module Utilities
    module Prompts
      module Agent
        # Return type hint formatting for tool descriptions.
        #
        # Generates readable type hints from output_type and output_schema:
        #   " -> String", " -> Array<{title, url}>", " -> Object{count, name}"
        module ReturnTypeHints
          def build_return_hint(tool)
            return "" unless tool.respond_to?(:output_type) && tool.output_type

            detailed_type_hint(tool) || " -> #{tool.output_type.capitalize}"
          end

          private

          def detailed_type_hint(tool)
            return nil unless tool.respond_to?(:output_schema) && tool.output_schema

            schema = tool.output_schema
            return format_schema_type(schema) if schema[:type] || schema["type"]

            " -> #{tool.output_type.capitalize}{#{keys_preview(schema)}}"
          end

          def format_schema_type(schema)
            type = schema[:type] || schema["type"]
            case type
            when "array" then format_array_type(schema)
            when "object" then format_object_type(schema)
            else " -> #{type.capitalize}"
            end
          end

          def format_array_type(schema)
            items = val(schema, :items)
            return " -> Array" unless items

            item_type = val(items, :type)
            props = item_type == "object" ? val(items, :properties) : nil
            props ? " -> Array<{#{keys_preview(props)}}>" : " -> Array<#{item_type&.capitalize || "Any"}>"
          end

          def format_object_type(schema)
            props = val(schema, :properties)
            props ? " -> Object{#{keys_preview(props)}}" : " -> Object"
          end

          def val(hash, key) = hash[key] || hash[key.to_s]

          def keys_preview(props)
            keys = props.keys.take(3).join(", ")
            props.size > 3 ? "#{keys}, ..." : keys
          end
        end
      end
    end
  end
end
