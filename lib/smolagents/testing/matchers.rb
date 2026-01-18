require_relative "matchers/dsl"
require_relative "matchers/agent_matchers"
require_relative "matchers/tool_matchers"
require_relative "matchers/model_matchers"
require_relative "matchers/result_matchers"

module Smolagents
  module Testing
    # Custom RSpec matchers for testing smolagents.
    #
    # Include this module in your RSpec configuration to get access to
    # agent-specific matchers that make tests more expressive.
    #
    # @example RSpec integration
    #   require "smolagents/testing"
    #
    #   RSpec.configure do |config|
    #     config.include Smolagents::Testing::Matchers
    #   end
    #
    # @example Using matchers
    #   describe "MyAgent" do
    #     it "completes successfully" do
    #       expect(agent).to complete_successfully.with_task("What is 2+2?")
    #     end
    #
    #     it "calls the search tool" do
    #       expect(spy_tool).to call_tool("search").with_arguments(query: "Ruby")
    #     end
    #
    #     it "exhausts all responses" do
    #       expect(model).to be_exhausted
    #     end
    #   end
    #
    # @see Helpers Helper methods for setting up tests
    # @see MockModel Mock model for deterministic testing
    module Matchers
      # Defines all matchers when included in a test context.
      #
      # @param base [Module] The module including Matchers
      def self.included(base)
        return unless defined?(RSpec::Matchers)

        base.include(AgentMatchers)
        base.include(ToolMatchers)
        base.include(ModelMatchers)
        base.include(ResultMatchers)
      end
    end
  end
end
