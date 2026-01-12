# frozen_string_literal: true

require "json"

module Smolagents
  module Concerns
    module Json
      def parse_json(string)
        JSON.parse(string)
      end

      def extract_json(data, *path)
        data&.dig(*path)
      end

      def to_json_string(data)
        JSON.generate(data)
      end
    end
  end
end
