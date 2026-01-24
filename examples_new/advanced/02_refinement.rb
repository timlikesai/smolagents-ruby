# Example: Self-Refinement
#
# Enable iterative refinement loops to improve results.
# Based on Self-Refine paper (arXiv:2303.17651) showing ~20% improvement.
#
# Run: ruby examples_new/advanced/02_refinement.rb
# Test: bundle exec rspec spec/examples/advanced/02_refinement_spec.rb

require_relative "../../lib/smolagents"

# =============================================================================
# BASIC REFINEMENT
# =============================================================================
#
# Enable refinement with defaults (3 iterations, execution feedback).

def create_agent_with_refinement(model)
  Smolagents.agent
            .model { model }
            .refine
            .build
end

# =============================================================================
# CUSTOM MAX ITERATIONS
# =============================================================================
#
# Limit the number of refinement attempts.

def create_agent_with_max_iterations(model, iterations: 2)
  Smolagents.agent
            .model { model }
            .refine(max_iterations: iterations)
            .build
end

# =============================================================================
# REFINEMENT WITH INTEGER SHORTHAND
# =============================================================================
#
# Pass an integer directly to set max_iterations.

def create_agent_with_refinement_shorthand(model)
  Smolagents.agent
            .model { model }
            .refine(5) # Same as refine(max_iterations: 5)
            .build
end

# =============================================================================
# FEEDBACK SOURCE
# =============================================================================
#
# Configure where feedback comes from:
#   :execution  - ExecutionOracle (default, good for small models)
#   :self       - Self-critique (requires capable models 7B+)
#   :evaluation - Use evaluation phase results

def create_agent_with_execution_feedback(model)
  Smolagents.agent
            .model { model }
            .refine(feedback: :execution)
            .build
end

# =============================================================================
# CONFIDENCE THRESHOLD
# =============================================================================
#
# Set minimum confidence to accept a result without refinement.

def create_agent_with_confidence_threshold(model)
  Smolagents.agent
            .model { model }
            .refine(max_iterations: 3, min_confidence: 0.9)
            .build
end

# =============================================================================
# RUNNING
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Self-Refinement Examples"
  puts ""
  puts "See the test file for deterministic examples:"
  puts "  bundle exec rspec spec/examples/advanced/02_refinement_spec.rb"
end
