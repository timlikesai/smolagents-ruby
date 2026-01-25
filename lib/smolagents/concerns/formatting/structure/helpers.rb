module Smolagents
  module Concerns
    module StructureFormatting
      # Shared helper methods for structure formatting.
      module Helpers
        module_function

        # Generate accessor syntax for a key.
        #
        # @param key [Symbol, Object] The key
        # @return [String] Accessor syntax (e.g., "[:name]" or "[\"key\"]")
        def accessor(key)
          key.is_a?(Symbol) ? "[:#{key}]" : "[#{key.inspect}]"
        end

        # Format a single key for display.
        #
        # @param key [Symbol, Object] The key
        # @return [String] Formatted key (e.g., ":name" or "\"key\"")
        def format_key(key)
          key.is_a?(Symbol) ? ":#{key}" : key.inspect
        end

        # Format multiple keys for display, truncating if too many.
        #
        # @param keys [Array] The keys to format
        # @return [String] Comma-separated keys with ellipsis if truncated
        def format_keys(keys)
          str = keys.take(MAX_KEYS).map { |k| format_key(k) }.join(", ")
          keys.size > MAX_KEYS ? "#{str}, ..." : str
        end

        # Sample a value for display, truncating if too long.
        #
        # @param value [Object] The value to sample
        # @return [String] Truncated inspect output
        def sample(value)
          str = value.inspect
          str.length > MAX_SAMPLE ? "#{str[0..MAX_SAMPLE]}..." : str
        rescue StandardError
          "?"
        end
      end
    end
  end
end
