# Infrastructure Design: Distributed Model Servers

## Current State

The ModelBuilder supports these local servers with hardcoded ports:
- `:lm_studio` → port 1234
- `:ollama` → port 11434
- `:llama_cpp` → port 8080
- `:vllm` → port 8000

This works for single-machine setups but doesn't express:
- Remote servers on different machines
- Multiple instances of the same server type
- Named server pools with different characteristics

## Proposed: Model Server Abstraction

### Option 1: URL-First Builder (Minimal Change)

```ruby
# Current - local only
Smolagents.model(:lm_studio).id("gpt-oss-20b").build

# Proposed - explicit URL override
Smolagents.model(:lm_studio)
  .at("http://mac-studio.reverse-bull.ts.net:1234")
  .id("gpt-oss-20b")
  .build

# Or even simpler
Smolagents.model
  .openai_compatible("http://mac-studio.reverse-bull.ts.net:1234/v1")
  .id("gpt-oss-20b")
  .build
```

**Pros:** Minimal API change, explicit, works today with manual config
**Cons:** Verbose when defining many models across servers

### Option 2: Named Server Registry

```ruby
# Define servers once at startup
Smolagents.configure do |c|
  c.servers = {
    mac_studio: {
      url: "http://mac-studio.reverse-bull.ts.net:1234/v1",
      models: ["gpt-oss-20b"],
      characteristics: { speed: :medium, capacity: :high }
    },
    macbook_fast: {
      url: "http://macbook-pro-m4.reverse-bull.ts.net:1234/v1",
      models: ["gpt-oss-20b", "gpt-oss-120b"],
      characteristics: { speed: :fast, capacity: :very_high }
    },
    llama_ultra: {
      url: "https://llama-cpp-ultra.reverse-bull.ts.net/v1",
      models: ["gpt-oss-20b"],
      characteristics: { speed: :very_fast, capacity: :medium }
    }
  }
end

# Reference by name
Smolagents.model(:mac_studio).id("gpt-oss-20b").build
Smolagents.model(:llama_ultra).id("gpt-oss-20b").build
```

**Pros:** DRY, expressive, characteristics can inform routing
**Cons:** New abstraction, configuration complexity

### Option 3: Discovery-Based (Dynamic)

```ruby
# Auto-discover available models from endpoints
cluster = Smolagents::ModelCluster.discover([
  "http://mac-studio.reverse-bull.ts.net:1234",
  "http://macbook-pro-m4.reverse-bull.ts.net:1234",
  "https://llama-cpp-ultra.reverse-bull.ts.net"
])

# Route requests based on model availability
model = cluster.model("gpt-oss-20b")  # Picks fastest available

# Or with constraints
model = cluster.model("gpt-oss-20b", prefer: :fastest)
model = cluster.model("gpt-oss-120b")  # Only on macbook_fast
```

**Pros:** Self-configuring, handles model availability dynamically
**Cons:** Complex, network calls at startup, harder to test

## Recommendation: Option 1 + Naming Convention

For now, use explicit URLs with a naming pattern in code:

```ruby
module MyInfrastructure
  MAC_STUDIO = "http://mac-studio.reverse-bull.ts.net:1234/v1"
  MACBOOK_PRO = "http://macbook-pro-m4.reverse-bull.ts.net:1234/v1"
  LLAMA_ULTRA = "https://llama-cpp-ultra.reverse-bull.ts.net/v1"

  def self.fast_20b
    Smolagents.model(:openai)
      .base_url(LLAMA_ULTRA)
      .id("gpt-oss-20b")
      .with_health_check
  end

  def self.big_120b
    Smolagents.model(:openai)
      .base_url(MACBOOK_PRO)
      .id("gpt-oss-120b")
      .with_health_check
  end

  def self.fast_20b_with_fallbacks
    fast_20b
      .with_fallback { Smolagents.model(:openai).base_url(MACBOOK_PRO).id("gpt-oss-20b").build }
      .with_fallback { Smolagents.model(:openai).base_url(MAC_STUDIO).id("gpt-oss-20b").build }
      .prefer_healthy
  end
end
```

## Gap Identified: Missing `base_url` Method

The ModelBuilder needs a `base_url` or `at` method to set `api_base` cleanly:

```ruby
# Currently requires:
.with_config(api_base: "http://...")

# Should support:
.base_url("http://...")
# or
.at("http://...")
```

## Gap Identified: Model Characteristics

We have no way to express model characteristics for intelligent routing:

```ruby
# Doesn't exist yet
model.with_characteristics(
  speed: :fast,
  context_window: 32_768,
  capabilities: [:vision, :tool_use, :json_mode]
)
```

Events exist for `ModelDiscovered` but aren't connected to routing decisions.

## Implementation Priority

1. **Low effort, high value:** Add `.base_url()` method to ModelBuilder
2. **Medium effort:** Allow passing characteristics in health_check for routing
3. **Future:** Model cluster/discovery abstraction
