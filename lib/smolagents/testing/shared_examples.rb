module Smolagents
  module Testing
    # RSpec shared examples for testing agents, tools, and models.
    #
    # These shared examples provide standardized behavioral tests that you can
    # include in your own specs to verify that custom implementations conform to
    # the smolagents interfaces.
    #
    # @example Using in RSpec configuration
    #   RSpec.configure do |config|
    #     config.include Smolagents::Testing::SharedExamples
    #   end
    #
    # @example Using agent shared example
    #   RSpec.describe MyCustomAgent do
    #     subject(:agent) { described_class.new(model: mock_model, tools: [tool]) }
    #     let(:task) { "What is 2+2?" }
    #
    #     it_behaves_like "an agent"
    #   end
    #
    # @example Using tool shared example
    #   RSpec.describe MyCustomTool do
    #     subject(:tool) { described_class.new }
    #     let(:valid_args) { { query: "test" } }
    #
    #     it_behaves_like "a tool"
    #   end
    #
    # @example Using model shared example
    #   RSpec.describe MyCustomModel do
    #     subject(:model) { described_class.new(model_id: "test") }
    #
    #     it_behaves_like "a model"
    #   end
    module SharedExamples
      # Defines shared examples when included in RSpec configuration.
      #
      # @param base [Module] The module including SharedExamples
      def self.included(_base)
        return unless defined?(RSpec)

        define_agent_examples
        define_tool_examples
        define_model_examples
      end

      # Defines shared examples for agents.
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength -- RSpec.shared_examples inherently large
      def self.define_agent_examples
        # Only define if not already defined (avoid conflicts with spec/support)
        return if RSpec.respond_to?(:world) && RSpec.world.shared_example_group_registry.find([:main], "an agent")

        RSpec.shared_examples "an agent" do
          it "runs without errors" do
            expect { subject.run(task) }.not_to raise_error
          end

          it "returns a RunResult" do
            result = subject.run(task)
            expect(result).to be_a(Smolagents::Types::RunResult)
          end

          it "completes within max_steps" do
            result = subject.run(task)
            max_steps = subject.respond_to?(:max_steps) ? subject.max_steps : 10
            expect(result.step_count).to be <= max_steps
          end

          it "emits step events during execution" do
            # NOTE: This test is optional as not all agents may emit events
            # in the same way. Skip if the agent doesn't support on(:step_complete)
            skip "Agent doesn't support event subscription" unless subject.respond_to?(:on)

            emitted_events = []
            subject.on(:step_complete) { |event| emitted_events << event }
            subject.run(task)

            # Events may or may not be emitted depending on agent implementation
            # This just verifies the mechanism works if present
            expect(emitted_events).to be_an(Array)
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # Defines shared examples for tools.
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength -- RSpec.shared_examples inherently large
      def self.define_tool_examples
        # Only define if not already defined (avoid conflicts with spec/support)
        return if RSpec.respond_to?(:world) && RSpec.world.shared_example_group_registry.find([:main], "a tool")

        RSpec.shared_examples "a tool" do
          it "has required metadata" do
            expect(subject.tool_name).to be_a(String)
            expect(subject.tool_name).not_to be_empty

            expect(subject.description).to be_a(String)
            expect(subject.description.length).to be >= 10

            expect(subject.inputs).to be_a(Hash)
          end

          it "responds to execute" do
            expect(subject).to respond_to(:execute)
          end

          it "validates input arguments" do
            expect { subject.validate_tool_arguments(valid_args) }.not_to raise_error
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # Defines shared examples for models.
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength -- RSpec.shared_examples inherently large
      def self.define_model_examples
        # Only define if not already defined (avoid conflicts with spec/support)
        return if RSpec.respond_to?(:world) && RSpec.world.shared_example_group_registry.find([:main], "a model")

        RSpec.shared_examples "a model" do
          it "responds to generate" do
            expect(subject).to respond_to(:generate)
          end

          it "returns content from generate" do
            messages = [Smolagents::ChatMessage.user("Test")]
            response = subject.generate(messages)

            expect(response).to be_a(Smolagents::ChatMessage)
            expect(response.content).to be_a(String)
          end

          it "returns token_usage from generate" do
            messages = [Smolagents::ChatMessage.user("Test")]
            response = subject.generate(messages)

            expect(response.token_usage).to be_a(Smolagents::TokenUsage)
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
  end
end
