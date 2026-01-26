module Smolagents
  module Concerns
    module StructureFormatting
      # Formatting for array values with access pattern guidance.
      module Arrays
        module_function

        # Describe an array with type info and access patterns.
        #
        # @param arr [Array] The array to describe
        # @param var [String] Variable name for display
        # @param depth [Integer] Current nesting depth
        # @return [String] Formatted description
        def describe_array(arr, var, depth)
          return "#{var} = [] (empty array)" if arr.empty?
          return "#{var} = #{arr.inspect}" if inline_array?(arr)

          lines = ["#{var} = Array[#{arr.size}]"]
          if arr.first.is_a?(Hash)
            add_hash_array_info(arr, var, depth, lines)
          else
            add_simple_array_info(arr, var, lines)
          end
          lines.join("\n")
        end

        # Check if array should be shown inline (small, all primitives).
        def inline_array?(arr)
          arr.size <= MAX_INLINE_ARRAY && all_primitives?(arr)
        end

        # Check if all array elements are primitive values.
        def all_primitives?(arr)
          arr.all? do |v|
            v.nil? || v.is_a?(Numeric) || v.is_a?(String) ||
              v.is_a?(Symbol) || v == true || v == false
          end
        end

        # Add info for an array of hashes.
        def add_hash_array_info(arr, var, depth, lines)
          lines << "  Each element has keys: #{Helpers.format_keys(arr.first.keys)}"
          lines << "  Access first: #{var}[0] or #{var}.first"
          first_key = arr.first.keys.first
          lines << "  Access field: #{var}.first#{Helpers.accessor(first_key)}"
          add_first_element_details(arr, var, depth, lines) if depth < MAX_DEPTH - 1
        end

        # Add details about the first element of an array of hashes.
        def add_first_element_details(arr, var, depth, lines)
          lines << "  First element:"
          arr.first.take(3).each do |k, v|
            nested_var = "#{var}.first#{Helpers.accessor(k)}"
            lines << "    #{StructureFormatting.describe(v, var: nested_var, depth: depth + 1)}"
          end
        end

        # Add info for a simple (non-hash) array.
        def add_simple_array_info(arr, var, lines)
          types = arr.take(5).map(&:class).uniq
          lines << "  Elements: #{types.size == 1 ? types.first.name : "Mixed"}"
          val_line = inline_array?(arr) ? arr.inspect : Helpers.sample(arr.first)
          lines << "  First: #{val_line}"
          lines << "  Access: #{var}[0] or #{var}.first"
        end
      end
    end
  end
end
