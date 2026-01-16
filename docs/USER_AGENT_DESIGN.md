# User-Agent Design for smolagents-ruby

## Overview

This document describes the comprehensive User-Agent design for smolagents-ruby that provides transparent AI agent identification while maintaining privacy and following RFC 7231 standards.

## Current Implementation

**Location:** `lib/smolagents/concerns/http.rb:40`

```ruby
DEFAULT_USER_AGENT = "Smolagents Ruby Agent/1.0 (https://github.com/timlikesai/smolagents-ruby)".freeze
```

**Coverage:** All tools using `Concerns::Http` (VisitWebpageTool, SearchTool, WikipediaSearchTool, etc.)

**Gap:** SpeechToTextTool bypasses Http concern and doesn't set User-Agent headers

## Design Principles

1. **RFC 7231 Compliance** - Follow standard HTTP User-Agent syntax
2. **AI Transparency** - Clearly identify as AI agent with model information
3. **Privacy-Safe** - No personal information or credentials
4. **Practical** - Users will actually use this (no email requirement)
5. **Contextual** - Include relevant agent/tool/model context
6. **Useful** - Help servers optimize responses and rate limiting

## User-Agent Format

```
[AgentName/Version] Smolagents/Version [Tool:Name] [Model:ModelID] Ruby/Version (+URL; bot)
```

### Components (in order)

1. **Agent Identity** (optional) - Specialized agent name and version
2. **Framework Identity** (required) - Always `Smolagents/VERSION`
3. **Tool Identity** (optional) - Specific tool making the request
4. **Model Identity** (optional) - AI model being used
5. **Runtime** (required) - Ruby version
6. **Contact Metadata** (required) - URL and bot identifier

### Example Outputs

**Minimal (no model context):**
```
Smolagents/0.0.1 Ruby/4.0.0 (+https://github.com/timlikesai/smolagents-ruby; bot)
```

**Tool-based request with model:**
```
Smolagents/0.0.1 Tool:VisitWebpage Model:gpt-4-turbo Ruby/4.0.0 (+https://github.com/timlikesai/smolagents-ruby; bot)
```

**Named agent with model:**
```
FactChecker/1.0 Smolagents/0.0.1 Model:claude-3-5-sonnet Ruby/4.0.0 (+https://github.com/timlikesai/smolagents-ruby; bot)
```

**Full context (agent + tool + model):**
```
ResearchAgent/2.0 Smolagents/0.0.1 Tool:DuckDuckGoSearch Model:llama-3.1-8b Ruby/4.0.0 (+https://github.com/timlikesai/smolagents-ruby; bot)
```

**Multi-agent coordinator:**
```
Coordinator/1.0 Smolagents/0.0.1 SubAgent:WebScraper Model:gemini-pro Ruby/4.0.0 (+https://github.com/timlikesai/smolagents-ruby; bot)
```

## Why Include Model Information?

### Benefits

1. **Server-side optimization** - Servers can tailor responses based on model capabilities
2. **Rate limiting intelligence** - Different models have different performance characteristics
3. **Analytics** - Understand which AI models are accessing services
4. **Transparency** - Clear disclosure that an AI is acting (not just a bot, but which AI)
5. **Debugging** - Helps diagnose model-specific behavior in logs
6. **Research** - Enables studying real-world AI agent behavior patterns

### Privacy Safety

- Model ID is not personal information
- Doesn't reveal user identity
- Already public information (model names are well-known)
- Can be sanitized to remove local paths

## Implementation Design

### Core UserAgent Class

```ruby
# lib/smolagents/user_agent.rb
module Smolagents
  class UserAgent
    DEFAULT_CONTACT_URL = "https://github.com/timlikesai/smolagents-ruby".freeze
    MAX_MODEL_ID_LENGTH = 64

    attr_reader :agent_name, :agent_version, :tool_name, :model_id, :contact_url

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
      @model_id = sanitize_model_id(model_id) if model_id
      @contact_url = contact_url || DEFAULT_CONTACT_URL
    end

    def to_s
      components = []

      components << "#{agent_name}/#{agent_version}" if agent_name
      components << "Smolagents/#{VERSION}"
      components << "Tool:#{tool_name}" if tool_name
      components << "Model:#{model_id}" if model_id
      components << "Ruby/#{RUBY_VERSION}"
      components << "(+#{contact_url}; bot)"

      components.join(' ')
    end

    # Create new UserAgent with tool context
    def with_tool(tool_name)
      self.class.new(
        agent_name: @agent_name,
        agent_version: @agent_version,
        tool_name: tool_name,
        model_id: @model_id,
        contact_url: @contact_url
      )
    end

    # Create new UserAgent with model context
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

    def sanitize_model_id(model_id)
      return nil unless model_id

      # Extract just the model name from various formats:
      # - "meta-llama/Llama-2-7b-chat-hf" -> "Llama-2-7b-chat-hf"
      # - "gpt-4-turbo-2024-04-09" -> "gpt-4-turbo"
      # - "./models/mistral.gguf" -> "mistral"

      sanitized = model_id
        .to_s
        .split('/')
        .last                                      # Remove path components
        .gsub(/\.(gguf|bin|pt|safetensors)$/, '') # Remove file extensions
        .gsub(/-\d{8,}$/, '')                     # Remove date stamps (8+ digits)
        .gsub(/[^a-zA-Z0-9\-_.]/, '_')            # Replace invalid chars
        .slice(0, MAX_MODEL_ID_LENGTH)            # Limit length

      sanitized.empty? ? nil : sanitized
    end
  end
end
```

### Agent Integration

```ruby
# In MultiStepAgent or CodeAgent
class CodeAgent < MultiStepAgent
  def initialize(model:, tools:, user_agent: nil, **kwargs)
    super

    # Build user agent with model context
    @user_agent = user_agent || UserAgent.new(
      agent_name: self.class.name.split('::').last,  # "CodeAgent"
      model_id: model.model_id,
      contact_url: kwargs[:contact_url]
    )

    # Pass to all tools
    tools.each do |tool|
      if tool.respond_to?(:user_agent=)
        tool.user_agent = @user_agent.with_tool(tool.class.name)
      end
    end
  end
end
```

### Tool Integration

```ruby
# In Concerns::Http
module Http
  def initialize(*args, **kwargs)
    super
    @user_agent = nil  # Will be set by agent or use default
  end

  def build_connection(url, resolved_ip: nil, allow_private: false)
    Faraday.new(url: url) do |faraday|
      # Use tool-specific user agent or fall back to default
      ua_string = case @user_agent
                  when UserAgent then @user_agent.to_s
                  when String then @user_agent
                  else DEFAULT_USER_AGENT
                  end

      faraday.headers["User-Agent"] = ua_string
      faraday.options.timeout = @timeout || DEFAULT_TIMEOUT

      faraday.use DnsRebindingGuard, resolved_ip: resolved_ip unless allow_private
      faraday.adapter Faraday.default_adapter
    end
  end
end
```

## Model ID Sanitization

The `sanitize_model_id` method removes potentially sensitive information while preserving useful model identification.

### Sanitization Examples

```ruby
sanitize_model_id("gpt-4-turbo-2024-04-09")
# => "gpt-4-turbo"

sanitize_model_id("meta-llama/Llama-2-7b-chat-hf")
# => "Llama-2-7b-chat-hf"

sanitize_model_id("claude-3-5-sonnet-20241022")
# => "claude-3-5-sonnet"

sanitize_model_id("./models/my-local-model.gguf")
# => "my-local-model"

sanitize_model_id("openai/gpt-4")
# => "gpt-4"

sanitize_model_id("HuggingFaceH4/zephyr-7b-beta")
# => "zephyr-7b-beta"
```

### Sanitization Rules

1. **Remove path components** - Strip directory paths and org prefixes
2. **Remove file extensions** - `.gguf`, `.bin`, `.pt`, `.safetensors`
3. **Remove date stamps** - Patterns like `-20241022` (8+ digits)
4. **Replace special characters** - Convert invalid chars to underscores
5. **Limit length** - Maximum 64 characters

## Privacy & Security

### Safe to Include

- ✅ Framework name/version (Smolagents/0.0.1)
- ✅ Tool name (Tool:VisitWebpage)
- ✅ Model identifier (Model:gpt-4-turbo)
- ✅ Ruby version (Ruby/4.0.0)
- ✅ Public contact URL (GitHub, docs site)
- ✅ Bot identifier (bot)

### Never Include

- ❌ Email addresses (people won't maintain this)
- ❌ API keys or credentials
- ❌ User identifiers or session tokens
- ❌ Full file paths (./models/user_private_model.gguf)
- ❌ Internal infrastructure details
- ❌ Private IP addresses or hostnames

## Configuration

Optional configuration via YAML:

```yaml
# config/user_agent.yml
development:
  contact_url: "http://localhost:3000/docs"
  include_model: true

production:
  contact_url: "https://docs.example.com/smolagents"
  include_model: true  # Or false for privacy

test:
  contact_url: "https://github.com/timlikesai/smolagents-ruby/issues"
  include_model: false  # Don't leak test model info
```

## Testing Strategy

```ruby
RSpec.describe Smolagents::UserAgent do
  describe "#to_s" do
    it "generates minimal user agent without optional fields" do
      ua = UserAgent.new
      expect(ua.to_s).to eq(
        "Smolagents/#{Smolagents::VERSION} Ruby/#{RUBY_VERSION} " \
        "(+https://github.com/timlikesai/smolagents-ruby; bot)"
      )
    end

    it "includes model information when provided" do
      ua = UserAgent.new(model_id: "gpt-4-turbo")
      expect(ua.to_s).to include("Model:gpt-4-turbo")
    end

    it "sanitizes model paths" do
      ua = UserAgent.new(model_id: "./models/llama-2.gguf")
      expect(ua.to_s).to include("Model:llama-2")
      expect(ua.to_s).not_to include(".gguf")
      expect(ua.to_s).not_to include("./models")
    end

    it "includes all components in correct order" do
      ua = UserAgent.new(
        agent_name: "TestAgent",
        agent_version: "2.0",
        tool_name: "Search",
        model_id: "claude-3-sonnet"
      )

      string = ua.to_s
      # Verify order: Agent, Framework, Tool, Model, Ruby, Contact
      expect(string).to match(
        /TestAgent\/2.0 Smolagents\/\S+ Tool:Search Model:claude-3-sonnet Ruby\/\S+ \(.+\)/
      )
    end
  end

  describe "#with_tool" do
    it "creates new instance with tool context" do
      base = UserAgent.new(model_id: "gpt-4")
      with_tool = base.with_tool("WebSearch")

      expect(with_tool.to_s).to include("Tool:WebSearch")
      expect(with_tool.to_s).to include("Model:gpt-4")
    end
  end

  describe "sanitize_model_id" do
    it "removes HuggingFace org prefixes" do
      ua = UserAgent.new(model_id: "meta-llama/Llama-2-7b")
      expect(ua.model_id).to eq("Llama-2-7b")
    end

    it "removes timestamp suffixes" do
      ua = UserAgent.new(model_id: "claude-3-sonnet-20241022")
      expect(ua.model_id).to eq("claude-3-sonnet")
    end

    it "limits length to max" do
      long_model = "a" * 100
      ua = UserAgent.new(model_id: long_model)
      expect(ua.model_id.length).to eq(64)
    end
  end
end
```

## Real-World Examples

### Web Scraping with Local Model

```
ResearchBot/1.0 Smolagents/0.0.1 Tool:VisitWebpage Model:llama-3.1-8b Ruby/4.0.0
(+https://github.com/timlikesai/smolagents-ruby; bot)
```

### Fact-Checking with GPT-4

```
FactChecker/2.0 Smolagents/0.0.1 Tool:GoogleSearch Model:gpt-4-turbo Ruby/4.0.0
(+https://docs.example.com/smolagents; bot)
```

### Background Processing

```
Smolagents/0.0.1 Tool:WikipediaSearch Ruby/4.0.0
(+https://github.com/timlikesai/smolagents-ruby; bot)
```

### Multi-Agent Team

```
TeamCoordinator/1.0 Smolagents/0.0.1 Model:claude-3-5-sonnet Ruby/4.0.0
(+https://github.com/timlikesai/smolagents-ruby; bot)
```

## Migration Path

### Phase 1: Foundation

Create `UserAgent` class with backward compatibility:

```ruby
# In lib/smolagents/concerns/http.rb
DEFAULT_USER_AGENT = UserAgent.new.to_s.freeze
```

### Phase 2: Agent Integration

Update agents to pass model context to tools:

```ruby
@user_agent = UserAgent.new(
  agent_name: self.class.name.split('::').last,
  model_id: model.model_id
)
```

### Phase 3: Tool Enhancement

Update tools to use tool-specific user agents:

```ruby
tool.user_agent = @user_agent.with_tool(tool.class.name)
```

## RFC 7231 Compliance

**Specification:** [RFC 7231 Section 5.5.3](https://datatracker.ietf.org/doc/html/rfc7231)

**Formal Syntax:**
```
User-Agent = product *( RWS ( product / comment ) )
product    = token ["/" product-version]
comment    = "(" *( ctext / quoted-pair / comment ) ")"
```

**Compliance:**
- ✅ Product identifiers in decreasing significance order
- ✅ Version numbers following each product
- ✅ Parenthetical comments for metadata
- ✅ Whitespace-separated components

## Best Practices

Based on research from [ScrapFly](https://scrapfly.io/blog/posts/user-agent-header-in-web-scraping), [http.dev](https://http.dev/user-agent), and [Wikimedia Foundation Policy](https://foundation.wikimedia.org/wiki/Policy:Wikimedia_Foundation_User-Agent_Policy):

1. **Transparency over stealth** - Identify clearly with contact information
2. **Standard format** - Follow RFC 7231 conventions
3. **Contact information** - Provide URL for webmaster communication
4. **Bot identification** - Include "bot" string for automated systems
5. **Model disclosure** - Identify which AI is acting (transparency)
6. **Respect robots.txt** - User-Agent should match claimed identity

## References

- [RFC 7231 - HTTP/1.1 Semantics](https://datatracker.ietf.org/doc/html/rfc7231)
- [User-Agent Header Guide - http.dev](https://http.dev/user-agent)
- [User Agents for Web Scraping - ScrapFly](https://scrapfly.io/blog/posts/user-agent-header-in-web-scraping)
- [Wikimedia Foundation User-Agent Policy](https://foundation.wikimedia.org/wiki/Policy:Wikimedia_Foundation_User-Agent_Policy)
- [User-Agent Header - MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/User-Agent)
