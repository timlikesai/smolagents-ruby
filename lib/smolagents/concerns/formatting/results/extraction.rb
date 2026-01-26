module Smolagents
  module Concerns
    module Results
      # Field extraction from raw API responses.
      #
      # Handles mapping raw result hashes to standardized formats using
      # string keys, array paths (for dig), or Procs for transformation.
      #
      # @example Basic key mapping
      #   extract_field(result, "title")  # => result["title"]
      #
      # @example Nested path extraction
      #   extract_field(result, ["data", "name"])  # => result.dig("data", "name")
      #
      # @example Proc transformation
      #   extract_field(result, ->(r) { r["url"]&.upcase })
      module Extraction
        # Map raw results to standardized field format.
        #
        # @param results [Array<Hash>] Raw result objects
        # @param fields [Hash<Symbol, String|Proc|Array>] Field mappings
        #   - String: Key to extract from result
        #   - Proc: Called with result, returns value
        #   - Array: Path for dig-style extraction
        # @return [Array<Hash>] Mapped results with specified keys
        def map_results(results, **fields)
          Array(results).map do |result|
            fields.transform_values { |spec| extract_field(result, spec) }
          end
        end

        # Extract nested results and map to standard format.
        #
        # @param data [Hash] Raw response data
        # @param path [Array<String>] Path to results array (for dig)
        # @param fields [Hash<Symbol, String|Proc|Array>] Field mappings
        # @return [Array<Hash>] Mapped results
        def extract_and_map(data, path:, **fields)
          results = data.dig(*path) || []
          map_results(results, **fields)
        end

        private

        # Extract a single field value using the given spec.
        #
        # @param result [Hash] Single result object
        # @param spec [String, Proc, Array] Extraction specification
        # @return [Object] Extracted value
        def extract_field(result, spec)
          case spec
          in Proc then spec.call(result)
          in Array then result.dig(*spec)
          else result[spec]
          end
        end
      end
    end
  end
end
