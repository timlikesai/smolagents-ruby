module Smolagents
  module Concerns
    # Formats data structures with access patterns for code agents.
    #
    # Shows type, shape, keys, and how to access nested data.
    # Deterministic - no LLM calls.
    #
    # @example Basic usage
    #   StructureFormatting.describe([{name: "Ruby"}])
    #   # => "result = Array[1]\n  Each element has keys: :name\n  ..."
    #
    # @example With custom variable name
    #   StructureFormatting.describe(data, var: "users")
    #   # => "users = Array[3]\n  ..."
    module StructureFormatting
      MAX_SAMPLE = 300
      MAX_KEYS = 8
      MAX_DEPTH = 3

      module_function

      # Describe a value with its type and access patterns.
      def describe(value, var: "result", depth: 0)
        case value
        when nil, true, false, Integer, Float, Symbol then describe_primitive(value, var)
        when String then describe_string(value, var)
        when Array then describe_array(value, var, depth)
        when Hash then describe_hash(value, var, depth)
        else describe_object(value, var, depth)
        end
      end

      def describe_primitive(value, var)
        formatted = if value.nil?
                      "nil"
                    else
                      (value.is_a?(Symbol) ? value.inspect : value)
                    end
        "#{var} = #{formatted}"
      end

      def describe_string(str, var)
        str.length <= 80 ? "#{var} = #{str.inspect}" : "#{var} = String(#{str.length} chars)"
      end

      def describe_array(arr, var, depth)
        return "#{var} = [] (empty array)" if arr.empty?

        lines = ["#{var} = Array[#{arr.size}]"]
        arr.first.is_a?(Hash) ? add_hash_array_info(arr, var, depth, lines) : add_simple_array_info(arr, var, lines)
        lines.join("\n")
      end

      def describe_hash(hash, var, depth)
        return "#{var} = {} (empty hash)" if hash.empty?

        lines = ["#{var} = Hash with keys: #{format_keys(hash.keys)}"]
        hash.take(4).each { |k, v| add_hash_entry(k, v, var, depth, lines) }
        lines.join("\n")
      end

      def describe_object(obj, var, depth)
        return describe_hash(obj.to_h, var, depth) if obj.respond_to?(:to_h)
        return describe_array(obj.to_a, var, depth) if obj.respond_to?(:to_a)

        "#{var} = #{obj.class.name}"
      end

      # Key/accessor formatting helpers
      def accessor(key) = key.is_a?(Symbol) ? "[:#{key}]" : "[#{key.inspect}]"
      def format_key(key) = key.is_a?(Symbol) ? ":#{key}" : key.inspect

      def format_keys(keys)
        str = keys.take(MAX_KEYS).map { |k| format_key(k) }.join(", ")
        keys.size > MAX_KEYS ? "#{str}, ..." : str
      end

      def sample(value)
        str = value.inspect
        str.length > MAX_SAMPLE ? "#{str[0..MAX_SAMPLE]}..." : str
      rescue StandardError
        "?"
      end

      # Private helpers for array/hash descriptions
      def add_hash_array_info(arr, var, depth, lines)
        lines << "  Each element has keys: #{format_keys(arr.first.keys)}"
        lines << "  Access first: #{var}[0] or #{var}.first"
        first_key = arr.first.keys.first
        lines << "  Access field: #{var}.first#{accessor(first_key)}"
        add_first_element_details(arr, var, depth, lines) if depth < MAX_DEPTH - 1
      end

      def add_first_element_details(arr, var, depth, lines)
        lines << "  First element:"
        arr.first.take(3).each do |k, v|
          lines << "    #{describe(v, var: "#{var}.first#{accessor(k)}", depth: depth + 1)}"
        end
      end

      def add_simple_array_info(arr, var, lines)
        types = arr.take(5).map(&:class).uniq
        lines << "  Elements: #{types.size == 1 ? types.first.name : "Mixed"}"
        lines << "  First: #{sample(arr.first)}"
        lines << "  Access: #{var}[0] or #{var}.first"
      end

      def add_hash_entry(key, value, var, depth, lines)
        path = "#{var}#{accessor(key)}"
        case value
        when Hash then add_nested_hash(value, path, depth, lines)
        when Array then add_nested_array(value, path, depth, lines)
        else lines << "#{path} = #{sample(value)}"
        end
      end

      def add_nested_hash(hash, path, depth, lines)
        lines << if depth < MAX_DEPTH - 1
                   describe_hash(hash, path, depth + 1)
                 else
                   "#{path} = Hash[#{hash.size} keys]"
                 end
      end

      def add_nested_array(arr, path, depth, lines)
        lines << "#{path} = Array[#{arr.size}]"
        return unless depth < MAX_DEPTH - 1 && arr.first.is_a?(Hash)

        lines << "  Access: #{path}[0] or #{path}.first"
        arr.first.take(2).each { |k, v| lines << "  #{path}[0]#{accessor(k)} = #{sample(v)}" }
      end
    end
  end
end
