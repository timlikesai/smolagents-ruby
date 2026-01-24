# Example: Evaluation (Metacognition)
#
# Evaluation checks goal achievement after each step.
# Based on AgentPRM (arXiv:2511.08325) metacognition patterns.
#
# Run: ruby examples_new/advanced/03_evaluation.rb
# Test: bundle exec rspec spec/examples/advanced/03_evaluation_spec.rb

require_relative "../../lib/smolagents"

# =============================================================================
# DEFAULT EVALUATION (ENABLED)
# =============================================================================
#
# Evaluation is ON by default. Agents check if they've achieved
# the goal after each step without relying on final_answer.

def create_agent_with_default_evaluation(model)
  Smolagents.agent
            .model { model }
            .build
end

# =============================================================================
# EXPLICIT EVALUATION
# =============================================================================
#
# Explicitly enable evaluation (same as default).

def create_agent_with_evaluation(model)
  Smolagents.agent
            .model { model }
            .evaluation(enabled: true)
            .build
end

# =============================================================================
# DISABLE EVALUATION
# =============================================================================
#
# Turn off metacognition for simpler agent behavior.

def create_agent_without_evaluation(model)
  Smolagents.agent
            .model { model }
            .evaluation(enabled: false)
            .build
end

# =============================================================================
# COMBINED ADVANCED FEATURES
# =============================================================================
#
# Combine planning, refinement, and evaluation for sophisticated agents.

def create_advanced_agent(model)
  Smolagents.agent
            .model { model }
            .planning(interval: 3)
            .refine(max_iterations: 2)
            .evaluation(enabled: true)
            .build
end

# =============================================================================
# RUNNING
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Evaluation Examples"
  puts ""
  puts "See the test file for deterministic examples:"
  puts "  bundle exec rspec spec/examples/advanced/03_evaluation_spec.rb"
end
