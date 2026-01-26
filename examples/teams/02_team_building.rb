# Example: Team Building
#
# Use TeamBuilder to create coordinated multi-agent teams.
# A coordinator agent manages specialized sub-agents.
#
# Run: ruby examples/teams/02_team_building.rb
# Test: bundle exec rspec spec/examples/teams/02_team_building_spec.rb

require_relative "../../lib/smolagents"

# =============================================================================
# BASIC TEAM
# =============================================================================
#
# Create a team with a coordinator and sub-agents.

def create_basic_team(coordinator_model, researcher_model, analyst_model)
  researcher = Smolagents.agent
                         .model { researcher_model }
                         .tool(:search, "Search", q: String) { |q:| "Found: #{q}" }
                         .build

  analyst = Smolagents.agent
                      .model { analyst_model }
                      .tool(:analyze, "Analyze", data: String) { |data:| "Analysis: #{data}" }
                      .build

  Smolagents.team
            .model { coordinator_model }
            .agent(researcher, as: "researcher")
            .agent(analyst, as: "analyst")
            .build
end

# =============================================================================
# TEAM WITH COORDINATION INSTRUCTIONS
# =============================================================================
#
# Provide instructions for how the coordinator should delegate.

def create_team_with_instructions(coordinator_model, *agent_models)
  researcher = Smolagents.agent.model { agent_models[0] }.build
  writer = Smolagents.agent.model { agent_models[1] }.build

  Smolagents.team
            .model { coordinator_model }
            .agent(researcher, as: "researcher")
            .agent(writer, as: "writer")
            .coordinate("First use researcher, then writer to format")
            .build
end

# =============================================================================
# TEAM WITH MAX STEPS
# =============================================================================
#
# Limit how many steps the coordinator can take.

def create_team_with_limits(coordinator_model, helper_model)
  helper = Smolagents.agent.model { helper_model }.build

  Smolagents.team
            .model { coordinator_model }
            .agent(helper, as: "helper")
            .max_steps(10)
            .build
end

# =============================================================================
# RUNNING
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Team Building Examples"
  puts ""
  puts "See the test file for deterministic examples:"
  puts "  bundle exec rspec spec/examples/teams/02_team_building_spec.rb"
end
