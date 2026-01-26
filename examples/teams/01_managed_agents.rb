# Example: Managed Agents
#
# Agents can delegate work to other agents. Two patterns:
# 1. AgentBuilder.managed_agent() - direct sub-agent attachment
# 2. TeamBuilder - hierarchical team with coordinator
#
# Run: ruby examples/teams/01_managed_agents.rb
# Test: bundle exec rspec spec/examples/teams/01_managed_agents_spec.rb

require_relative "../../lib/smolagents"

# =============================================================================
# AGENTBUILDER MANAGED_AGENT (DIRECT)
# =============================================================================
#
# Attach managed agents directly to an agent via the builder DSL.

def create_agent_with_helper(parent_model, helper_model)
  helper = Smolagents.agent
                     .model { helper_model }
                     .tool(:lookup, "Look up a fact", topic: String) { |topic:| "Fact about #{topic}" }
                     .build

  Smolagents.agent
            .model { parent_model }
            .managed_agent(helper, as: :researcher)
            .build
end

# =============================================================================
# MULTIPLE MANAGED AGENTS
# =============================================================================
#
# Attach multiple sub-agents via chained managed_agent calls.

def create_agent_with_specialists(parent_model, researcher_model, writer_model)
  researcher = Smolagents.agent
                         .model { researcher_model }
                         .tool(:search, "Search for info", q: String) { |q:| "Results for: #{q}" }
                         .build

  writer = Smolagents.agent
                     .model { writer_model }
                     .tool(:format, "Format text", text: String) { |text:| text.upcase }
                     .build

  Smolagents.agent
            .model { parent_model }
            .managed_agent(researcher, as: :researcher)
            .managed_agent(writer, as: :writer)
            .build
end

# =============================================================================
# TEAMBUILDER PATTERN
# =============================================================================
#
# For hierarchical teams, use TeamBuilder with coordination instructions.

def create_team_with_coordination(coordinator_model, helper_model)
  helper = Smolagents.agent
                     .model { helper_model }
                     .tool(:lookup, "Look up a fact", topic: String) { |topic:| "Fact about #{topic}" }

  Smolagents.team
            .model { coordinator_model }
            .agent(helper, as: "researcher")
            .coordinate("Delegate research tasks to researcher")
            .build
end

# =============================================================================
# RUNNING
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Managed Agents Examples"
  puts ""
  puts "See the test file for deterministic examples:"
  puts "  bundle exec rspec spec/examples/teams/01_managed_agents_spec.rb"
end
