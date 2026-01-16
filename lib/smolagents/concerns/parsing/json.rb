require "json"

module Smolagents
  module Concerns
    # JSON parsing and serialization utilities for API tools.
    #
    # Provides simple wrappers around Ruby's JSON library with
    # convenient extraction methods for nested data structures.
    # Includes UTF-8 sanitization to handle malformed responses
    # from external APIs (e.g., ArXiv).
    #
    # @example Parse and extract data
    #   class MyApiTool < Tool
    #     include Concerns::Json
    #
    #     def execute(query:)
    #       response = get("https://api.example.com/search?q=#{query}")
    #       data = parse_json(response.body)
    #       results = extract_json(data, "response", "items")
    #       format_results(results)
    #     end
    #   end
    #
    # @example Deep extraction with dig-style path
    #   # Given: { "data" => { "users" => [{ "name" => "Alice" }] } }
    #   users = extract_json(data, "data", "users")
    #   # => [{ "name" => "Alice" }]
    #
    # @example Serialize data for responses
    #   to_json_string({ status: "ok", count: 42 })
    #   # => '{"status":"ok","count":42}'
    #
    # @see SearchTool Which includes this for JSON API responses
    # @see GoogleSearchTool Example of JSON API consumption
    module Json
      # Sanitize string to valid UTF-8.
      # Replaces invalid/undefined bytes with replacement character.
      # @param string [String] String to sanitize
      # @return [String] Valid UTF-8 string
      def sanitize_utf8(string)
        return "" if string.nil?

        string.encode("UTF-8", invalid: :replace, undef: :replace, replace: "\uFFFD")
      end

      # Parse a JSON string into Ruby data structures.
      # Sanitizes UTF-8 before parsing to handle malformed responses.
      # @param string [String] JSON-encoded string
      # @return [Hash, Array] Parsed data
      # @raise [JSON::ParserError] If the string is not valid JSON
      def parse_json(string)
        JSON.parse(sanitize_utf8(string))
      end

      # Extract nested data using dig-style path.
      # @param data [Hash, nil] Parsed JSON data
      # @param path [Array<String>] Keys to traverse (e.g., "response", "items")
      # @return [Object, nil] Value at path or nil if path doesn't exist
      def extract_json(data, *path)
        data&.dig(*path)
      end

      # Serialize Ruby data to JSON string.
      # Recursively sanitizes all string values to valid UTF-8.
      # @param data [Hash, Array] Data to serialize
      # @return [String] JSON-encoded string
      def to_json_string(data)
        JSON.generate(sanitize_for_json(data))
      end

      private

      # Recursively sanitize data structure for JSON serialization.
      def sanitize_for_json(data)
        case data
        when String
          sanitize_utf8(data)
        when Hash
          data.transform_values { |v| sanitize_for_json(v) }
        when Array
          data.map { |v| sanitize_for_json(v) }
        else
          data
        end
      end
    end
  end
end
