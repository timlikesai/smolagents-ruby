# Core Builder Features Demo

## What We've Built

All builders now have these **ESSENTIAL** features built-in from the foundation:

1. ✅ **Validation** - Catch errors early with helpful messages
2. ✅ **Introspection** - `.help` for REPL-friendly development
3. ✅ **Immutability Controls** - `.freeze!` for production safety
4. ✅ **Convenience Aliases** - Ergonomic shortcuts
5. ✅ **Pattern Matching** - Full Data.define support

## Live Examples

### 1. REPL-Friendly Help System

```ruby
builder = Smolagents.model(:openai)
puts builder.help

# Output:
# ModelBuilder - Available Methods
# ============================================================
#
# Required:
#   .id(model_id)
#     Set the model identifier (e.g., 'gpt-4', 'claude-3-opus')
#
# Optional:
#   .api_key(key) (aliases: key)
#     Set API authentication key
#   .temperature(temp) (aliases: temp)
#     Set temperature (0.0-2.0, default: 1.0)
#   .max_tokens(tokens) (aliases: tokens)
#     Set maximum tokens in response (1-100000)
#   .timeout(seconds)
#     Set request timeout in seconds (1-600)
#   ...
#
# Current Configuration:
#   #<ModelBuilder type=openai model_id=nil>
#
# Pattern Matching:
#   case builder
#   in ModelBuilder[type_or_model, configuration]
#     # Match and destructure
#   end
#
# Build:
#   .build - Create the configured object
```

### 2. Validation with Helpful Error Messages

```ruby
# Temperature out of range
builder.temperature(5.0)
# => ArgumentError: Invalid value for temperature: 5.0.
#    Set temperature (0.0-2.0, default: 1.0)

# Empty model ID
builder.id("")
# => ArgumentError: Invalid value for id: "".
#    Set the model identifier (e.g., 'gpt-4', 'claude-3-opus')

# Negative timeout
builder.timeout(-10)
# => ArgumentError: Invalid value for timeout: -10.
#    Set request timeout in seconds (1-600)

# Valid values work fine
builder.temperature(0.7)    # ✅
builder.id("gpt-4")         # ✅
builder.timeout(30)         # ✅
```

### 3. Production-Safe Freeze

```ruby
# Build a production configuration
PRODUCTION_MODEL = Smolagents.model(:openai)
  .id("gpt-4")
  .api_key(ENV["OPENAI_API_KEY"])
  .temperature(0.7)
  .timeout(30)
  .freeze!   # Lock it down!

# Configuration is preserved
PRODUCTION_MODEL.config[:model_id]     # => "gpt-4"
PRODUCTION_MODEL.config[:temperature]  # => 0.7

# But modifications are prevented
PRODUCTION_MODEL.temperature(0.5)
# => FrozenError: Cannot modify frozen Smolagents::Builders::ModelBuilder

PRODUCTION_MODEL.api_key("different-key")
# => FrozenError: Cannot modify frozen Smolagents::Builders::ModelBuilder

# Can still build the frozen config
model = PRODUCTION_MODEL.build  # ✅ Works fine!
```

### 4. Convenience Aliases

```ruby
# Long form
builder
  .temperature(0.7)
  .max_tokens(4000)
  .api_key("sk-...")

# Short form (same result)
builder
  .temp(0.7)         # alias for temperature
  .tokens(4000)      # alias for max_tokens
  .key("sk-...")     # alias for api_key

# Aliases validate too
builder.temp(5.0)
# => ArgumentError: Invalid value for temperature: 5.0.
#    Set temperature (0.0-2.0, default: 1.0)
```

### 5. Pattern Matching

```ruby
# Match on model type
def configure_for_provider(builder)
  case builder
  in Smolagents::Builders::ModelBuilder[type_or_model: :openai]
    builder.timeout(30)
  in Smolagents::Builders::ModelBuilder[type_or_model: :anthropic]
    builder.timeout(60)
  else
    builder
  end
end

# Destructure configuration
builder = Smolagents.model(:openai)
  .id("gpt-4")
  .temperature(0.7)
  .max_tokens(8000)

case builder
in Smolagents::Builders::ModelBuilder[configuration: { model_id:, temperature:, max_tokens: }]
  puts "Model: #{model_id} @ #{temperature}°C, max #{max_tokens} tokens"
end
# => "Model: gpt-4 @ 0.7°C, max 8000 tokens"
```

### 6. Full Integration Example

```ruby
# Build a production-ready model with all features
model = Smolagents.model(:openai)
  .id("gpt-4")                    # Validates: must be non-empty string
  .key(ENV["OPENAI_API_KEY"])     # Alias for api_key, validates non-empty
  .temp(0.7)                      # Alias for temperature, validates 0.0-2.0
  .tokens(4000)                   # Alias for max_tokens, validates 1-100000
  .timeout(30)                    # Validates 1-600 seconds
  .with_retry(max_attempts: 3)    # Reliability features still work!
  .freeze!                        # Lock it down for production

# Can introspect at any point
puts model.help

# Can pattern match
case model
in Smolagents::Builders::ModelBuilder[configuration: { model_id: "gpt-4", temperature: t }]
  puts "GPT-4 configured at #{t} temperature"
end

# Build and use
llm = model.build
result = llm.generate(...)
```

## Implementation Details

### Base Module (lib/smolagents/builders/base.rb)

The foundation for all builder features:

- **`builder_method`** - DSL for registering methods with validation
- **`.help`** - Generates formatted help text
- **`.freeze!`** - Returns frozen builder variant
- **`validate!`** - Runs registered validators
- **`check_frozen!`** - Prevents modification of frozen builders

### Integration Pattern

```ruby
ModelBuilder = Data.define(:type_or_model, :configuration) do
  include Base  # Get all core features

  # Register methods with validation
  builder_method :temperature,
    description: "Set temperature (0.0-2.0, default: 1.0)",
    validates: ->(v) { v.is_a?(Numeric) && v >= 0.0 && v <= 2.0 },
    aliases: [:temp]

  # Implement method with validation
  def temperature(temp)
    check_frozen!       # Prevent modification if frozen
    validate!(:temperature, temp)  # Run validator
    with_config(temperature: temp)  # Return new instance
  end
  alias_method :temp, :temperature  # Add alias
end
```

## Test Coverage

145 total specs covering:
- ✅ Help system shows all methods, descriptions, aliases
- ✅ Validation catches invalid values with helpful messages
- ✅ Freeze prevents modifications while preserving config
- ✅ Convenience aliases work and validate
- ✅ Pattern matching supports destructuring
- ✅ Immutability and method chaining work correctly
- ✅ DSL.Builder factory creates custom builders with all features

All builders enhanced: ModelBuilder (38 specs), AgentBuilder (32 specs), TeamBuilder (24 specs), Base features (22 specs), DSL.Builder (29 specs).

## Unified Builder Factory (DSL.Builder)

Create custom builders with all core features automatically:

```ruby
# Define a custom builder
CustomBuilder = Smolagents::DSL.Builder(:target, :configuration) do
  # Register methods with validation
  builder_method :max_retries,
    description: "Set maximum retry attempts (1-10)",
    validates: ->(v) { v.is_a?(Integer) && (1..10).cover?(v) },
    aliases: [:retries]

  # Default configuration
  def self.default_configuration
    { max_retries: 3, timeout: 30, enabled: true }
  end

  # Factory method
  def self.create(target)
    new(target: target, configuration: default_configuration)
  end

  # Builder method with validation
  def max_retries(n)
    check_frozen!
    validate!(:max_retries, n)
    with_config(max_retries: n)
  end
  alias_method :retries, :max_retries

  # Build the final object
  def build
    { target: target, **configuration.except(:__frozen__) }
  end

  private

  def with_config(**kwargs)
    self.class.new(target: target, configuration: configuration.merge(kwargs))
  end
end

# Usage - automatically gets all core features
builder = CustomBuilder.create(:my_target)
builder.help                  # ✅ Shows all methods
builder.max_retries(7)        # ✅ Validates range
builder.max_retries(15)       # ❌ ArgumentError: Invalid value
frozen = builder.freeze!      # ✅ Production-safe
frozen.max_retries(5)         # ❌ FrozenError

# Pattern matching works automatically
case builder
in CustomBuilder[target: :my_target, configuration: { max_retries: }]
  puts "Retries: #{max_retries}"
end
```

## Next Steps

1. ✅ **Roll out to AgentBuilder** - COMPLETED
2. ✅ **Roll out to TeamBuilder** - COMPLETED
3. ✅ **Standardize callbacks** - COMPLETED
4. ✅ **Unified Builder Factory** - COMPLETED (DSL.Builder)
5. **Comprehensive Composition Tests** - Test all DSLs working together

## Why This Matters

These aren't "nice-to-have" features - they're **essential for production use**:

1. **Validation** catches configuration errors at setter time, not at runtime
2. **Help** makes the DSL discoverable without reading docs
3. **Freeze** prevents accidental modification of production configs
4. **Aliases** reduce verbosity without sacrificing clarity
5. **Pattern Matching** enables powerful routing and conditional logic

Every builder gets these for free by including `Base` - no duplication, perfect consistency.
