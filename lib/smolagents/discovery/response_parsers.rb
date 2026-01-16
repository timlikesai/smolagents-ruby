require "json"
require_relative "model_builder"

module Smolagents
  module Discovery
    # Parses model responses from different API formats.
    module ResponseParsers
      module_function

      def parse_lm_studio_response(response, ctx)
        parse_json_models(response, "models") { |m| ModelBuilder.from_lm_studio(ctx, m) }
      end

      def parse_v0_response(response, ctx)
        parse_json_models(response, "data") { |m| ModelBuilder.from_v0(ctx, m) }
      end

      def parse_v1_response(response, ctx)
        parse_json_models(response, "data") { |m| ModelBuilder.from_v1(ctx, m) }
      end

      def parse_native_response(response, ctx)
        parse_json_models(response, "models") { |m| ModelBuilder.from_native(ctx, m) }
      end

      def parse_json_models(response, key, &)
        data = JSON.parse(response)
        (data[key] || []).map(&)
      rescue JSON::ParserError
        []
      end
    end
  end
end
