require "json"

module Smolagents
  module Concerns
    # JSON parsing and serialization utilities for API tools.
    #
    # Provides simple wrappers around Ruby's JSON library with
    # convenient extraction methods for nested data structures.
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
      # Parse a JSON string into Ruby data structures.
      # @param string [String] JSON-encoded string
      # @return [Hash, Array] Parsed data
      # @raise [JSON::ParserError] If the string is not valid JSON
      def parse_json(string)
        JSON.parse(string)
      end

      # Extract nested data using dig-style path.
      # @param data [Hash, nil] Parsed JSON data
      # @param path [Array<String>] Keys to traverse (e.g., "response", "items")
      # @return [Object, nil] Value at path or nil if path doesn't exist
      def extract_json(data, *path)
        data&.dig(*path)
      end

      # Serialize Ruby data to JSON string.
      # @param data [Hash, Array] Data to serialize
      # @return [String] JSON-encoded string
      def to_json_string(data)
        JSON.generate(data)
      end
    end
  end
end
