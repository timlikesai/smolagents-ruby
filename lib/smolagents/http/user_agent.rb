require_relative "user_agent/sanitizer"
require_relative "user_agent/builder"

module Smolagents
  module Http
    # RFC 7231 compliant User-Agent builder with AI agent context.
    #
    # Builds User-Agent strings that identify AI agents transparently while
    # maintaining privacy. Supports agent, tool, and model context propagation.
    #
    # @example Basic usage
    #   ua = UserAgent.new
    #   ua.to_s
    #   # => "Smolagents/0.0.1 Ruby/4.0.0 (+https://github.com/timlikesai/smolagents-ruby; bot)"
    #
    # @example With model context
    #   ua = UserAgent.new(model_id: "gemma-3n-e4b-it-q8_0")
    #   ua.to_s
    #   # => "Smolagents/0.0.1 Model:gemma-3n-e4b-it-q8_0 Ruby/4.0.0 (+...; bot)"
    #
    # @example With tool context
    #   base_ua = UserAgent.new(model_id: "gpt-oss-20b")
    #   tool_ua = base_ua.with_tool("VisitWebpage")
    #
    # @see https://datatracker.ietf.org/doc/html/rfc7231#section-5.5.3 RFC 7231 User-Agent
    class UserAgent
      # Default contact URL for webmasters
      DEFAULT_CONTACT_URL = "https://github.com/timlikesai/smolagents-ruby".freeze

      # Maximum length for model ID
      MAX_MODEL_ID_LENGTH = 64

      attr_reader :agent_name, :agent_version, :tool_name, :model_id, :contact_url

      # Creates a new UserAgent with the given context.
      #
      # @param agent_name [String, nil] Custom agent name
      # @param agent_version [String, nil] Agent version
      # @param tool_name [String, nil] Tool making the request
      # @param model_id [String, nil] AI model identifier (sanitized automatically)
      # @param contact_url [String, nil] Contact URL for webmasters
      def initialize(agent_name: nil, agent_version: nil, tool_name: nil, model_id: nil, contact_url: nil)
        @agent_name = agent_name
        @agent_version = agent_version
        @tool_name = tool_name
        @model_id = Sanitizer.sanitize(model_id, max_length: MAX_MODEL_ID_LENGTH)
        @contact_url = contact_url || DEFAULT_CONTACT_URL
      end

      # Generates RFC 7231 compliant User-Agent string.
      #
      # @return [String] User-Agent header value
      def to_s = Builder.build(self)

      # Creates new UserAgent with tool context added.
      #
      # @param tool_name [String] Name of the tool
      # @return [UserAgent] New instance with tool context
      def with_tool(tool_name)
        with(tool_name:)
      end

      # Creates new UserAgent with model context added.
      #
      # @param model_id [String] Model identifier
      # @return [UserAgent] New instance with model context
      def with_model(model_id)
        with(model_id:)
      end

      private

      # Creates a new instance with updated attributes.
      #
      # @param overrides [Hash] Attributes to override
      # @return [UserAgent] New instance
      def with(**overrides)
        self.class.new(
          agent_name: @agent_name,
          agent_version: @agent_version,
          tool_name: @tool_name,
          model_id: @model_id,
          contact_url: @contact_url,
          **overrides
        )
      end
    end
  end
end
