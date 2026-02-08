module Smolagents
  module Utilities
    module Prompts
      module Agent
        # YARD-style tool formatting for agent prompts.
        # Renders tools as documented method stubs models recognize from Ruby training data.
        module ToolFormatting
          RUBY_TYPE_MAP = {
            "string" => "String", "integer" => "Integer", "number" => "Numeric",
            "float" => "Float", "boolean" => "Boolean", "array" => "Array",
            "object" => "Hash", "any" => "Object"
          }.freeze

          def format_tool(tool)
            return "- #{tool}" if tool.is_a?(String)

            final_answer?(tool) ? format_final_answer(tool) : format_standard_tool(tool)
          end

          private

          def final_answer?(tool) = tool.respond_to?(:name) && tool.name.to_s == "final_answer"

          def format_final_answer(tool)
            lines = ["# >>> REQUIRED: Return your final answer <<<"]
            yard_params(tool, lines)
            lines.push("# @example", '#   final_answer(answer: "The result is 42")',
                       "def final_answer(#{kwparams(tool)}) = ...")
            lines.join("\n")
          end

          def format_standard_tool(tool)
            lines = ["# #{tool.description}"]
            yard_params(tool, lines)
            yard_return(tool, lines)
            lines.push("# @example", "#   result = #{example_call(tool)}",
                       "def #{tool.name}(#{kwparams(tool)}) = ...")
            lines.join("\n")
          end

          def yard_params(tool, lines)
            (tool.inputs || {}).each do |name, spec|
              lines << "# @param #{name} [#{ruby_type(spec)}] #{val(spec, :description)}"
            end
          end

          def yard_return(tool, lines)
            return unless tool.respond_to?(:output_type) && tool.output_type

            lines << "# @return [#{detailed_return(tool)}]"
          end

          def detailed_return(tool)
            return rtype(tool.output_type) unless tool.respond_to?(:output_schema) && tool.output_schema

            schema_type(tool.output_schema)
          end

          def schema_type(schema)
            case val(schema, :type)
            when "array" then array_type(schema)
            when "object" then object_type(schema)
            when nil then "Hash{#{typed_keys(schema)}}"
            else rtype(val(schema, :type))
            end
          end

          def array_type(schema)
            items = val(schema, :items)
            return "Array" unless items

            props = val(items, :type) == "object" ? val(items, :properties) : nil
            props ? "Array<Hash{#{typed_keys(props)}}>" : "Array<#{rtype(val(items, :type))}>"
          end

          def object_type(schema)
            (props = val(schema, :properties)) ? "Hash{#{typed_keys(props)}}" : "Hash"
          end

          def typed_keys(props)
            entries = props.take(3).map { |k, v| "#{k}: #{rtype(val(v, :type))}" }
            props.size > 3 ? "#{entries.join(", ")}, ..." : entries.join(", ")
          end

          def ruby_type(spec)
            base = rtype(val(spec, :type))
            val(spec, :nullable) ? "#{base}, nil" : base
          end

          def val(hash, key) = hash[key] || hash[key.to_s]
          def rtype(type) = RUBY_TYPE_MAP[type.to_s.downcase] || type.to_s.capitalize
          def kwparams(tool) = (tool.inputs || {}).keys.map { "#{it}:" }.join(", ")

          def example_call(tool)
            inputs = tool.inputs || {}
            args = inputs.map { |n, s| example_arg(n, s) }
            args.empty? ? "#{tool.name}()" : "#{tool.name}(#{args.join(", ")})"
          end

          def example_arg(name, spec)
            value = Templates.example_for_type(val(spec, :type), val(spec, :description), name.to_s)
            "#{name}: #{value.inspect}"
          end
        end
      end
    end
  end
end
