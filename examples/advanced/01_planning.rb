# Example: Planning Mode
#
# Enable strategic planning to improve task decomposition.
# Based on Pre-Act pattern (arXiv:2505.09970) showing 70% improvement.
#
# Run: ruby examples/advanced/01_planning.rb
# Test: bundle exec rspec spec/examples/advanced/01_planning_spec.rb

require_relative "../../lib/smolagents"

# =============================================================================
# BASIC PLANNING
# =============================================================================
#
# Enable planning with defaults (interval: 3 steps).

def create_agent_with_planning(model)
  Smolagents.agent
            .model { model }
            .planning
            .build
end

# =============================================================================
# CUSTOM PLANNING INTERVAL
# =============================================================================
#
# Update the plan every N steps.

def create_agent_with_planning_interval(model, interval: 5)
  Smolagents.agent
            .model { model }
            .planning(interval:)
            .build
end

# =============================================================================
# PLANNING WITH INTEGER SHORTHAND
# =============================================================================
#
# Pass an integer directly to set the interval.

def create_agent_with_planning_shorthand(model)
  Smolagents.agent
            .model { model }
            .planning(7) # Same as planning(interval: 7)
            .build
end

# =============================================================================
# DISABLE PLANNING
# =============================================================================
#
# Explicitly disable planning.

def create_agent_without_planning(model)
  Smolagents.agent
            .model { model }
            .planning(false)
            .build
end

# =============================================================================
# RUNNING
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Planning Mode Examples"
  puts ""
  puts "See the test file for deterministic examples:"
  puts "  bundle exec rspec spec/examples/advanced/01_planning_spec.rb"
end
