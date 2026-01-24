# Example: Managed Agents
#
# Agents can delegate work to other agents using TeamBuilder.
# The coordinator agent calls child agents like tools.
#
# Run: ruby examples_new/teams/01_managed_agents.rb
# Test: bundle exec rspec spec/examples/teams/01_managed_agents_spec.rb

require_relative "../../lib/smolagents"

# =============================================================================
# BASIC TEAM WITH HELPER
# =============================================================================
#
# Create a team where the coordinator delegates to a helper agent.

def create_team_with_helper(coordinator_model, helper_model)
  helper = Smolagents.agent
                     .model { helper_model }
                     .tool(:lookup, "Look up a fact", topic: String) { |topic:| "Fact about #{topic}" }

  Smolagents.team
            .model { coordinator_model }
            .agent(helper, as: "researcher")
            .build
end

# =============================================================================
# TEAM WITH MULTIPLE AGENTS
# =============================================================================
#
# Create a team with multiple specialized agents.

def create_team_with_specialists(coordinator_model, researcher_model, writer_model)
  researcher = Smolagents.agent
                         .model { researcher_model }
                         .tool(:search, "Search for info", q: String) { |q:| "Results for: #{q}" }

  writer = Smolagents.agent
                     .model { writer_model }
                     .tool(:format, "Format text", text: String) { |text:| text.upcase }

  Smolagents.team
            .model { coordinator_model }
            .agent(researcher, as: "researcher")
            .agent(writer, as: "writer")
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
