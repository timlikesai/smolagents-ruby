require_relative "helpers/multi_step_builder"
require_relative "helpers/model_helpers"
require_relative "helpers/agent_helpers"
require_relative "helpers/tool_helpers"
require_relative "helpers/fixtures"
require_relative "helpers/spy_tool"

module Smolagents
  module Testing
    # Helper methods for testing smolagents.
    #
    # Include this module in your test suite to get convenient helper methods
    # for creating mock models and test fixtures.
    #
    # @example RSpec integration
    #   require "smolagents/testing"
    #
    #   RSpec.configure do |config|
    #     config.include Smolagents::Testing::Helpers
    #   end
    #
    # @example Using helpers
    #   describe "MyAgent" do
    #     it "answers questions" do
    #       model = mock_model_for_single_step("42")
    #       agent = Smolagents.agent.model { model }.build
    #       expect(agent.run("question").output).to eq("42")
    #     end
    #   end
    #
    # @see MockModel The underlying mock model class
    # @see Matchers Custom RSpec matchers for agents
    module Helpers
      include Helpers::ModelHelpers
      include Helpers::AgentHelpers
      include Helpers::ToolHelpers
    end

    # Expose Fixtures at Testing level for convenient access.
    # @see Helpers::Fixtures
    Fixtures = Helpers::Fixtures
  end
end
