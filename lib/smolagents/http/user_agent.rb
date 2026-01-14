require_relative "../version"

module Smolagents
  module Http
    # RFC 7231 compliant User-Agent builder with AI agent context.
    #
    # Builds User-Agent strings that identify AI agents transparently while
    # maintaining privacy. Supports agent, tool, and model context propagation.
    #
    # The User-Agent format follows RFC 7231 and includes:
    # - Agent name and version (optional)
    # - Library identifier (Smolagents/VERSION)
    # - Tool context (optional)
    # - Model identifier (sanitized for privacy)
    # - Ruby version
    # - Contact URL and bot indicator
    #
    # @example Basic usage
    #   ua = UserAgent.new
    #   ua.to_s
    #   # => "Smolagents/0.0.1 Ruby/4.0.0 (+https://github.com/timlikesai/smolagents-ruby; bot)"
    #
    # @example With model context (local model)
    #   ua = UserAgent.new(model_id: "gemma-3n-e4b-it-q8_0")
    #   ua.to_s
    #   # => "Smolagents/0.0.1 Model:gemma-3n-e4b-it-q8_0 Ruby/4.0.0 (+...; bot)"
    #
    # @example With tool context (via with_tool)
    #   base_ua = UserAgent.new(model_id: "gpt-oss-20b-mxfp4")
    #   tool_ua = base_ua.with_tool("VisitWebpage")
    #   tool_ua.to_s
    #   # => "Smolagents/0.0.1 Tool:VisitWebpage Model:gpt-oss-20b-mxfp4 Ruby/4.0.0 (+...; bot)"
    #
    # @example Named agent with full context
    #   ua = UserAgent.new(
    #     agent_name: "ResearchAgent",
    #     agent_version: "2.0",
    #     tool_name: "DuckDuckGoSearch",
    #     model_id: "nemotron-3-nano-30b-a3b-iq4_nl"
    #   )
    #   ua.to_s
    #   # => "ResearchAgent/2.0 Smolagents/0.0.1 Tool:DuckDuckGoSearch Model:nemotron-3-nano-30b-a3b-iq4_nl Ruby/4.0.0 (+...; bot)"
    #
    # @example Using the re-exported class
    #   # Both of these work:
    #   ua = Smolagents::UserAgent.new
    #   ua = Smolagents::Http::UserAgent.new
    #
    # @see https://datatracker.ietf.org/doc/html/rfc7231#section-5.5.3 RFC 7231 User-Agent
    class UserAgent
      # Default contact URL for webmasters to reach out about bot behavior
      DEFAULT_CONTACT_URL = "https://github.com/timlikesai/smolagents-ruby".freeze

      # Maximum length for model ID to prevent overly long User-Agent strings
      MAX_MODEL_ID_LENGTH = 64

      # @return [String, nil] Custom agent name (e.g., "ResearchAgent")
      attr_reader :agent_name

      # @return [String, nil] Agent version (e.g., "2.0")
      attr_reader :agent_version

      # @return [String, nil] Tool making the request (e.g., "VisitWebpage")
      attr_reader :tool_name

      # @return [String, nil] Sanitized AI model identifier
      attr_reader :model_id

      # @return [String] Contact URL for webmasters
      attr_reader :contact_url

      # Creates a new UserAgent with the given context.
      #
      # @param agent_name [String, nil] Custom agent name (e.g., "ResearchAgent")
      # @param agent_version [String, nil] Agent version (e.g., "2.0")
      # @param tool_name [String, nil] Tool making the request (e.g., "VisitWebpage")
      # @param model_id [String, nil] AI model identifier (sanitized automatically)
      # @param contact_url [String, nil] Contact URL for webmasters
      def initialize(
        agent_name: nil,
        agent_version: nil,
        tool_name: nil,
        model_id: nil,
        contact_url: nil
      )
        @agent_name = agent_name
        @agent_version = agent_version
        @tool_name = tool_name
        @model_id = sanitize_model_id(model_id)
        @contact_url = contact_url || DEFAULT_CONTACT_URL
      end

      # Generates RFC 7231 compliant User-Agent string.
      #
      # Format: [AgentName/Version] Smolagents/VERSION [Tool:Name] [Model:ID] Ruby/VERSION (+URL; bot)
      #
      # @return [String] User-Agent header value
      def to_s
        components = []

        components << "#{agent_name}/#{agent_version}" if agent_name
        components << "Smolagents/#{VERSION}"
        components << "Tool:#{tool_name}" if tool_name
        components << "Model:#{model_id}" if model_id
        components << "Ruby/#{RUBY_VERSION}"
        components << "(+#{contact_url}; bot)"

        components.join(" ")
      end

      # Creates new UserAgent with tool context added.
      #
      # Returns a new instance with the tool_name set, preserving all other fields.
      # This is useful for propagating context when a tool makes HTTP requests.
      #
      # @param tool_name [String] Name of the tool
      # @return [UserAgent] New instance with tool context
      #
      # @example
      #   base = UserAgent.new(model_id: "gpt-4")
      #   tool_specific = base.with_tool("VisitWebpage")
      def with_tool(tool_name)
        self.class.new(
          agent_name: @agent_name,
          agent_version: @agent_version,
          tool_name:,
          model_id: @model_id,
          contact_url: @contact_url
        )
      end

      # Creates new UserAgent with model context added.
      #
      # Returns a new instance with the model_id set, preserving all other fields.
      # The model_id will be sanitized automatically.
      #
      # @param model_id [String] Model identifier
      # @return [UserAgent] New instance with model context
      #
      # @example
      #   base = UserAgent.new(agent_name: "MyAgent")
      #   with_model = base.with_model("llama-3-8b")
      def with_model(model_id)
        self.class.new(
          agent_name: @agent_name,
          agent_version: @agent_version,
          tool_name: @tool_name,
          model_id:,
          contact_url: @contact_url
        )
      end

      private

      # Sanitizes model ID by removing sensitive/unnecessary information.
      #
      # Transformations:
      # - Removes path components (org prefixes, directories)
      # - Removes file extensions (.gguf, .bin, .pt, .safetensors)
      # - Removes date stamps (8+ digit suffixes like -20241022)
      # - Replaces invalid characters with underscores
      # - Limits length to MAX_MODEL_ID_LENGTH
      #
      # @param model_id [String, nil] Raw model identifier
      # @return [String, nil] Sanitized model identifier
      def sanitize_model_id(model_id)
        return nil if model_id.nil? || model_id.to_s.empty?

        base = model_id.to_s.split("/").last
        return nil if base.nil? || base.empty?

        sanitized = base
                    .gsub(/\.(gguf|bin|pt|safetensors)$/i, "")   # Remove file extensions
                    .gsub(/-\d{8,}$/, "")                        # Remove date stamps (8+ digits)
                    .gsub(/[^a-zA-Z0-9\-_.]/, "_")               # Replace invalid chars
                    .slice(0, MAX_MODEL_ID_LENGTH)               # Limit length

        sanitized.empty? ? nil : sanitized
      end
    end
  end
end
