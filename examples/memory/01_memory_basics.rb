# Example: Memory Configuration
#
# Configure how agents manage conversation history using token budgets
# and memory strategies. Essential for long-running tasks.
#
# Run: ruby examples/memory/01_memory_basics.rb
# Test: bundle exec rspec spec/examples/memory/01_memory_basics_spec.rb

require_relative "../../lib/smolagents"

# =============================================================================
# DEFAULT MEMORY (UNLIMITED)
# =============================================================================
#
# By default, agents keep full history with no truncation.

def create_agent_with_default_memory(model)
  Smolagents.agent
            .model { model }
            .memory
            .build
end

# =============================================================================
# TOKEN BUDGET
# =============================================================================
#
# Set a token budget to automatically mask old observations.
# This enables .memory(budget:) which defaults to :mask strategy.

def create_agent_with_budget(model, budget: 50_000)
  Smolagents.agent
            .model { model }
            .memory(budget:)
            .build
end

# =============================================================================
# MEMORY STRATEGIES
# =============================================================================
#
# Available strategies:
#   :full      - Keep everything (default, no truncation)
#   :mask      - Replace old observations with placeholder
#   :summarize - LLM summarizes old context (advanced)
#   :hybrid    - Combine masking with summarization

def create_agent_with_mask_strategy(model)
  Smolagents.agent
            .model { model }
            .memory(budget: 100_000, strategy: :mask)
            .build
end

def create_agent_with_full_strategy(model)
  Smolagents.agent
            .model { model }
            .memory(strategy: :full)
            .build
end

# =============================================================================
# PRESERVE RECENT STEPS
# =============================================================================
#
# When masking, preserve N most recent action steps.

def create_agent_with_preserved_steps(model)
  Smolagents.agent
            .model { model }
            .memory(budget: 50_000, strategy: :mask, preserve_recent: 5)
            .build
end

# =============================================================================
# MEMORY CONFIG DIRECTLY
# =============================================================================
#
# For advanced use, create MemoryConfig directly.

def create_memory_config_directly
  Smolagents::Types::MemoryConfig.masked(budget: 8000, preserve_recent: 3)
end

# =============================================================================
# RUNNING
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Memory Configuration Examples"
  puts ""
  puts "See the test file for deterministic examples:"
  puts "  bundle exec rspec spec/examples/memory/01_memory_basics_spec.rb"
end
