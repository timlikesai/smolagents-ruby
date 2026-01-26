# Example 01: Hello World
#
# The simplest possible agent - no tools, just a model answering a question.
# This demonstrates the minimal DSL required to create and run an agent.
#
# Run: ruby examples/basics/01_hello_world.rb
# Test: bundle exec rspec spec/examples/basics/01_hello_world_spec.rb

require_relative "../../lib/smolagents"

# =============================================================================
# MINIMAL AGENT
# =============================================================================
#
# The only required configuration is a model. Everything else has sensible defaults.

def create_minimal_agent(model)
  Smolagents.agent
            .model { model }
            .build
end

# =============================================================================
# WITH INSTRUCTIONS
# =============================================================================
#
# Add custom instructions to guide the agent's behavior.

def create_agent_with_instructions(model)
  Smolagents.agent
            .model { model }
            .instructions("Always respond in haiku format (5-7-5 syllables).")
            .build
end

# =============================================================================
# WITH PERSONA
# =============================================================================
#
# Use `.as(:persona)` for pre-defined instruction sets.

def create_agent_with_persona(model)
  Smolagents.agent
            .model { model }
            .as(:researcher)
            .build
end

# =============================================================================
# RUNNING THE AGENT
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  # For real usage, configure your model:
  #
  #   model = Smolagents::OpenAIModel.new(api_key: ENV["OPENAI_API_KEY"])
  #   agent = create_minimal_agent(model)
  #   result = agent.run("What is the capital of France?")
  #   puts result
  #
  # See examples/basics/02_model_configuration.rb for model setup details.

  puts "This example requires a configured model."
  puts "See the test file for deterministic examples using MockModel."
  puts ""
  puts "Test: bundle exec rspec spec/examples/basics/01_hello_world_spec.rb"
end
