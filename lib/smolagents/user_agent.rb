require_relative "version"

module Smolagents
  # RFC 7231 compliant User-Agent builder with AI agent context.
  #
  # Builds User-Agent strings that identify AI agents transparently while
  # maintaining privacy. Supports agent, tool, and model context propagation.
  #
  # @example Basic usage
  #   ua = UserAgent.new
  #   ua.to_s
  #   # => "Smolagents/0.0.1 Ruby/3.3.0 (+https://github.com/timlikesai/smolagents-ruby; bot)"
  #
  # @example With model context
  #   ua = UserAgent.new(model_id: "gpt-4-turbo")
  #   ua.to_s
  #   # => "Smolagents/0.0.1 Model:gpt-4-turbo Ruby/3.3.0 (+...; bot)"
  #
  # @example With tool context (via with_tool)
  #   base_ua = UserAgent.new(model_id: "claude-3-sonnet")
  #   tool_ua = base_ua.with_tool("VisitWebpage")
  #   tool_ua.to_s
  #   # => "Smolagents/0.0.1 Tool:VisitWebpage Model:claude-3-sonnet Ruby/3.3.0 (+...; bot)"
  #
  # @example Named agent with full context
  #   ua = UserAgent.new(
  #     agent_name: "ResearchAgent",
  #     agent_version: "2.0",
  #     tool_name: "DuckDuckGoSearch",
  #     model_id: "llama-3.1-8b"
  #   )
  #   ua.to_s
  #   # => "ResearchAgent/2.0 Smolagents/0.0.1 Tool:DuckDuckGoSearch Model:llama-3.1-8b Ruby/3.3.0 (+...; bot)"
  #
  # @see https://datatracker.ietf.org/doc/html/rfc7231#section-5.5.3 RFC 7231 User-Agent
  class UserAgent
    DEFAULT_CONTACT_URL = "https://github.com/timlikesai/smolagents-ruby".freeze
    MAX_MODEL_ID_LENGTH = 64

    attr_reader :agent_name, :agent_version, :tool_name, :model_id, :contact_url

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
    # @param tool_name [String] Name of the tool
    # @return [UserAgent] New instance with tool context
    def with_tool(tool_name)
      self.class.new(
        agent_name: @agent_name,
        agent_version: @agent_version,
        tool_name: tool_name,
        model_id: @model_id,
        contact_url: @contact_url
      )
    end

    # Creates new UserAgent with model context added.
    #
    # @param model_id [String] Model identifier
    # @return [UserAgent] New instance with model context
    def with_model(model_id)
      self.class.new(
        agent_name: @agent_name,
        agent_version: @agent_version,
        tool_name: @tool_name,
        model_id: model_id,
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
