require_relative "structure/helpers"
require_relative "structure/primitives"
require_relative "structure/arrays"
require_relative "structure/hashes"

module Smolagents
  module Concerns
    # Formats data structures with access patterns for code agents.
    #
    # Shows type, shape, keys, and how to access nested data.
    # Deterministic - no LLM calls. Delegates to focused sub-modules
    # for each data type.
    #
    # @example Basic usage
    #   StructureFormatting.describe([{name: "Ruby"}])
    #   # => "result = Array[1]\n  Each element has keys: :name\n  ..."
    #
    # @example With custom variable name
    #   StructureFormatting.describe(data, var: "users")
    #   # => "users = Array[3]\n  ..."
    #
    # @see StructureFormatting::Primitives For primitive value formatting
    # @see StructureFormatting::Arrays For array formatting
    # @see StructureFormatting::Hashes For hash formatting
    module StructureFormatting
      MAX_SAMPLE = 300
      MAX_KEYS = 8
      MAX_DEPTH = 3
      MAX_INLINE_ARRAY = 10

      module_function

      # Describe a value with its type and access patterns.
      #
      # Dispatches to the appropriate sub-module based on value type.
      #
      # @param value [Object] The value to describe
      # @param var [String] Variable name for display (default: "result")
      # @param depth [Integer] Current nesting depth (default: 0)
      # @return [String] Human-readable description with access patterns
      def describe(value, var: "result", depth: 0)
        case value
        when nil, true, false, Integer, Float, Symbol then Primitives.describe_primitive(value, var)
        when String then Primitives.describe_string(value, var)
        when Range then Primitives.describe_range(value, var)
        when Array then Arrays.describe_array(value, var, depth)
        when Hash then Hashes.describe_hash(value, var, depth)
        else describe_object(value, var, depth)
        end
      end

      # Describe an arbitrary object by converting to hash or array.
      #
      # @param obj [Object] The object to describe
      # @param var [String] Variable name for display
      # @param depth [Integer] Current nesting depth
      # @return [String] Description based on to_h or to_a conversion
      def describe_object(obj, var, depth)
        if obj.respond_to?(:to_h)
          Hashes.describe_hash(obj.to_h, var, depth)
        elsif obj.respond_to?(:to_a)
          Arrays.describe_array(obj.to_a, var, depth)
        else
          "#{var} = #{obj.class.name}"
        end
      end
    end
  end
end
