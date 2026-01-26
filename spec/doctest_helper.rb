# Doctest helper for yard-doctest
#
# Configures yard-doctest to test @example blocks in YARD documentation.
# Examples are executed to verify they don't raise errors.
# Examples with #=> assertions are also checked for correct return values.
#
# Usage:
#   bundle exec rake yard:doctest
#
# PHILOSOPHY: Examples should be self-contained and testable. Each example
# shows the setup it needs, making it clear to users what's required.
# This approach ensures documentation stays accurate and tested in CI.
#
# Only load when running yard doctest (not regular rspec)
return unless defined?(YARD::Doctest)

# =============================================================================
# MOCK CLIENTS FOR EXTERNAL SERVICES
#
# These stubs allow model examples to run without real API connections.
# The examples show real usage patterns; these mocks make them testable.
# We set up mocks BEFORE loading smolagents so the gems see them.
# =============================================================================

# Set dummy API keys before gems load
ENV["ANTHROPIC_API_KEY"] = "test-key-for-doctest"
ENV["OPENAI_API_KEY"] = "test-key-for-doctest"

# Pre-load gems with mock clients to prevent real API initialization
require "openai"
require "anthropic"

# Stub the OpenAI client to return mock responses
module OpenAI
  class Client
    alias original_initialize initialize

    def initialize(**opts)
      # Accept any options without validation
      @access_token = opts[:access_token] || "mock"
      @uri_base = opts[:uri_base]
    end

    def chat(_parameters:)
      { "choices" => [{ "message" => { "content" => "Mock response", "role" => "assistant" } }],
        "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5, "total_tokens" => 15 } }
    end
  end
end

# Stub the Anthropic client to return mock responses
module Anthropic
  class Client
    alias original_initialize initialize

    def initialize(**opts)
      # Accept any options without validation
      @access_token = opts[:access_token] || "mock"
    end

    def messages(_parameters:)
      { "content" => [{ "type" => "text", "text" => "Mock response" }],
        "usage" => { "input_tokens" => 10, "output_tokens" => 5 } }
    end
  end
end

# Now load smolagents with mocked clients
require "smolagents"
require "smolagents/testing"

YARD::Doctest.configure do |doctest|
  # ===========================================================================
  # SKIP PATTERNS
  # Only skip examples that truly cannot be tested
  # ===========================================================================

  # Skip Testing.configure_rspec - requires RSpec to be loaded first
  doctest.skip "Smolagents::Testing.configure_rspec"

  # Skip Agent class and method examples that reference undefined variables
  # These are illustrative examples showing usage patterns
  doctest.skip "Smolagents::Agents::Agent"
  doctest.skip "Smolagents::Agents.create"

  # Skip AgentRuntime class and method examples that require complex setup
  doctest.skip "Smolagents::Agents::AgentRuntime"

  # Skip examples that require external services or complex state
  doctest.skip "Smolagents::DSL#event_docs" # Long output, not suitable for doctest

  # ===========================================================================
  # GLOBAL BEFORE HOOK
  # Ensure smolagents is loaded and ready
  # ===========================================================================

  doctest.before do
    Smolagents.reset_configuration! if Smolagents.respond_to?(:reset_configuration!)
  end

  # ===========================================================================
  # AFTER HOOK
  # ===========================================================================

  doctest.after do
    Smolagents.reset_configuration! if Smolagents.respond_to?(:reset_configuration!)
  end
end
