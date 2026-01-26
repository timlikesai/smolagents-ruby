module Smolagents
  module Concerns
    module StructureFormatting
      # Formatting for hash values with key enumeration and nested access.
      module Hashes
        module_function

        # Describe a hash with its keys and sample values.
        #
        # @param hash [Hash] The hash to describe
        # @param var [String] Variable name for display
        # @param depth [Integer] Current nesting depth
        # @return [String] Formatted description
        def describe_hash(hash, var, depth)
          return "#{var} = {} (empty hash)" if hash.empty?

          lines = ["#{var} = Hash with keys: #{Helpers.format_keys(hash.keys)}"]
          hash.take(4).each { |k, v| add_hash_entry(k, v, var, depth, lines) }
          lines.join("\n")
        end

        # Add a single hash entry to the output lines.
        def add_hash_entry(key, value, var, depth, lines)
          path = "#{var}#{Helpers.accessor(key)}"
          case value
          when Hash then add_nested_hash(value, path, depth, lines)
          when Array then add_nested_array(value, path, depth, lines)
          else lines << "#{path} = #{Helpers.sample(value)}"
          end
        end

        # Add a nested hash description.
        def add_nested_hash(hash, path, depth, lines)
          lines << if depth < MAX_DEPTH - 1
                     describe_hash(hash, path, depth + 1)
                   else
                     "#{path} = Hash[#{hash.size} keys]"
                   end
        end

        # Add a nested array description.
        def add_nested_array(arr, path, depth, lines)
          lines << "#{path} = Array[#{arr.size}]"
          return unless depth < MAX_DEPTH - 1 && arr.first.is_a?(Hash)

          lines << "  Access: #{path}[0] or #{path}.first"
          arr.first.take(2).each do |k, v|
            lines << "  #{path}[0]#{Helpers.accessor(k)} = #{Helpers.sample(v)}"
          end
        end
      end
    end
  end
end
