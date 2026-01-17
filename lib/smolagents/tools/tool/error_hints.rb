module Smolagents
  module Tools
    class Tool
      # Provides targeted error hints for common agent mistakes.
      #
      # Analyzes errors and provides ONE concise, actionable hint when appropriate.
      # Avoids overwhelming models with too much information.
      module ErrorHints
        # Enhances an error with a single targeted hint if applicable.
        #
        # @param error [Exception] The original error
        # @param tool_name [String] Name of the tool that failed
        # @param inputs [Hash] The inputs that were passed to the tool
        # @param expected_inputs [Hash, nil] The tool's input specification
        # @return [Exception] Enhanced error with hint, or original if no hint applies
        def self.enhance_error(error, tool_name:, inputs: {}, expected_inputs: nil)
          hint = find_best_hint(error, tool_name:, inputs:, expected_inputs:)
          return error unless hint

          create_enhanced_error(error, "#{error.message}\n\nTIP: #{hint}")
        end

        # Finds the single most relevant hint for this error.
        def self.find_best_hint(error, tool_name:, inputs:, expected_inputs: nil)
          case error
          when NameError
            hint_for_name_error(error, inputs)
          when TypeError
            hint_for_type_error(error)
          when ArgumentError
            hint_for_argument_error(error, tool_name, expected_inputs)
          when NoMethodError
            hint_for_no_method_error(error)
          when ZeroDivisionError
            "Check your expression for division by zero."
          end
        end

        # Hint for undefined variable - usually string literal vs interpolation mistake.
        def self.hint_for_name_error(error, inputs)
          var_name = extract_var_name(error)
          return nil unless var_name

          # Check if var appears in any string input
          inputs.each_value do |value|
            next unless value.is_a?(String) && value.include?(var_name)

            # Concise hint with the fix
            return "Use \#{#{var_name}} for interpolation, or just: #{var_name} * 2 (tool results support arithmetic)"
          end

          nil
        end

        # Hint for type errors - usually wrong argument type.
        def self.hint_for_type_error(error)
          msg = error.message

          return unless msg.include?("no implicit conversion") && msg.include?("into String")

          "Expression must be a string: calculate(expression: \"25 * 4\") not calculate(expression: 25 * 4)"
        end

        # Hint for argument errors - wrong number or missing keyword.
        def self.hint_for_argument_error(error, tool_name, expected_inputs)
          msg = error.message
          valid_keywords = format_valid_keywords(expected_inputs)

          if msg.include?("wrong number of arguments")
            example = valid_keywords || "arg: value"
            "#{tool_name} is a function. Call it: #{tool_name}(#{example})"
          elsif msg.include?("missing keyword") && (match = msg.match(/missing keyword:\s*:?(\w+)/))
            keyword = match[1]
            "Missing required argument. Use: #{tool_name}(#{keyword}: \"...\")"
          elsif msg.include?("unknown keyword") && (match = msg.match(/unknown keyword:\s*:?(\w+)/))
            wrong_keyword = match[1]
            if valid_keywords
              "Unknown '#{wrong_keyword}:'. Valid arguments: #{valid_keywords}"
            else
              "Unknown '#{wrong_keyword}:'. Use help(:#{tool_name}) for correct arguments."
            end
          elsif msg.include?("unknown keyword")
            if valid_keywords
              "Wrong argument name. Valid arguments: #{valid_keywords}"
            else
              "Wrong argument name. Use help(:#{tool_name}) to see correct arguments."
            end
          end
        end

        # Formats expected inputs as keyword argument examples.
        def self.format_valid_keywords(expected_inputs)
          return nil unless expected_inputs&.any?

          expected_inputs.keys.map { |k| "#{k}: ..." }.join(", ")
        end

        # Hint for method not found - usually calling method on nil or wrong type.
        def self.hint_for_no_method_error(error)
          msg = error.message

          if msg.include?("nil:NilClass")
            "Variable is nil. Capture tool results: result = calculate(...), then use result."
          elsif msg.include?("for ") && msg.include?(":String")
            "Can't call that method on a String. For arithmetic, use: result.to_i * 2"
          elsif msg.include?(":Integer") || msg.include?(":Float")
            "Can't call that method on a number. For string operations, use: result.to_s"
          end
        end

        # Extracts variable name from NameError message.
        def self.extract_var_name(error)
          match = error.message.match(/undefined local variable or method [`'](\w+)[`']/)
          match&.[](1)
        end

        # Creates error with enhanced message.
        def self.create_enhanced_error(original, message)
          original.class.new(message)
        end
      end
    end
  end
end
