module Smolagents
  module Concerns
    module StructureFormatting
      # Formatting for primitive values: nil, booleans, numbers, symbols, strings, ranges.
      module Primitives
        module_function

        # Describe a primitive value (nil, boolean, number, symbol).
        #
        # @param value [nil, true, false, Integer, Float, Symbol] The value
        # @param var [String] Variable name for display
        # @return [String] Formatted description
        def describe_primitive(value, var)
          formatted = case value
                      when nil then "nil"
                      when Symbol then value.inspect
                      else value
                      end
          "#{var} = #{formatted}"
        end

        # Describe a string value, truncating if too long.
        #
        # @param str [String] The string value
        # @param var [String] Variable name for display
        # @return [String] Formatted description
        def describe_string(str, var)
          if str.length <= 80
            "#{var} = #{str.inspect}"
          else
            "#{var} = String(#{str.length} chars)"
          end
        end

        # Describe a range value.
        #
        # @param range [Range] The range value
        # @param var [String] Variable name for display
        # @return [String] Formatted description
        def describe_range(range, var) = "#{var} = #{range.inspect}"
      end
    end
  end
end
