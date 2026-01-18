module Smolagents
  module Testing
    module Helpers
      # Agent-related test helper methods.
      #
      # Provides convenience methods for creating test agents, capturing
      # agent execution steps, and asserting on agent results.
      #
      # @example Creating a test agent
      #   agent = test_agent(model_response: "42", tools: [search_tool])
      #   result = agent.run("What is the answer?")
      #
      # @example Capturing steps
      #   steps = capture_agent_steps(agent) { agent.run("task") }
      #   expect(steps.size).to eq(3)
      module AgentHelpers
        # Creates an agent configured with a mock model response.
        #
        # @param model_response [String, ChatMessage] Response to return
        # @param tools [Array<Tool>] Tools to include
        # @param agent_class [Class, nil] Custom agent class
        # @return [Agent] Configured agent
        def test_agent(model_response:, tools: [], agent_class: nil)
          model = mock_model_that_responds(model_response)
          build_agent(model, tools, agent_class)
        end

        # Captures agent step callbacks during execution.
        #
        # @param agent [Agent] The agent to monitor
        # @yield Block that triggers agent execution
        # @return [Array<ActionStep>] Steps captured during execution
        def capture_agent_steps(agent)
          [].tap do |steps|
            agent.register_callback(:on_step_complete) { |_, monitor| steps << monitor }
            yield
          end
        end

        # Asserts that an agent result indicates success.
        #
        # @param result [Object] The agent run result
        def assert_agent_success(result)
          expect(result).not_to be_nil
          expect(result).to be_a(String).or be_a(Hash).or be_a(Smolagents::RunResult)
        end

        # Returns a matcher for agent errors.
        #
        # @param error_class [Class] Expected error class
        # @return [Object] RSpec error matcher
        def raise_agent_error(error_class) = raise_error(error_class)

        # Creates a temporary workspace directory for agent tests.
        #
        # @yield [String] The path to the temporary directory
        # @return [Object] The result of the block
        def with_agent_workspace(&)
          Dir.mktmpdir("smolagents-test-", &)
        end

        private

        def build_agent(model, tools, agent_class)
          if agent_class
            agent_class.new(model:, tools:)
          else
            Agents::Agent.new(model:, tools:)
          end
        end
      end
    end
  end
end
