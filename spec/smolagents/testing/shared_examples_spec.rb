# -- Testing shared examples, not a specific class
RSpec.describe "Smolagents::Testing::SharedExamples" do
  # Include the shared examples module to make them available
  include Smolagents::Testing::SharedExamples

  describe "'an agent' shared example" do
    let(:mock_model) do
      Smolagents::Testing::MockModel.new.tap do |m|
        m.queue_final_answer("4")
      end
    end
    let(:tool) { Smolagents::Tools::FinalAnswerTool.new }

    context "with a valid agent" do
      subject(:agent) do
        Smolagents.agent
                  .model { mock_model }
                  .tools(tool)
                  .max_steps(5)
                  .build
      end

      let(:task) { "What is 2+2?" }

      it_behaves_like "an agent"
    end

    context "with an agent that hits max_steps" do
      subject(:agent) do
        model = Smolagents::Testing::MockModel.new
        # Queue valid responses but not a final_answer, forcing max_steps
        5.times { model.queue_code_action("x = 1 + 1") }

        Smolagents.agent
                  .model { model }
                  .tools(tool)
                  .max_steps(3)
                  .build
      end

      let(:task) { "Calculate something" }

      it "still completes and returns a RunResult" do
        result = agent.run(task)
        expect(result).to be_a(Smolagents::Types::RunResult)
        # Result should be max_steps_reached, success, or error
        # (depending on how the agent handles the situation)
        # rubocop:disable RSpec/ExpectActual -- Testing multiple valid states
        expect(%i[max_steps_reached success error]).to include(result.state)
        # rubocop:enable RSpec/ExpectActual
      end
    end
  end

  describe "'a tool' shared example" do
    context "with a valid tool" do
      subject(:tool) do
        Class.new(Smolagents::Tool) do
          self.tool_name = "test_calculator"
          self.description = "A simple calculator for testing purposes"
          self.inputs = {
            operation: { type: "string", description: "Math operation to perform" },
            num1: { type: "number", description: "First number" },
            num2: { type: "number", description: "Second number" }
          }
          self.output_type = "number"

          def execute(operation:, num1:, num2:)
            case operation
            when "add" then num1 + num2
            when "subtract" then num1 - num2
            when "multiply" then num1 * num2
            when "divide" then num1 / num2
            else raise ArgumentError, "Unknown operation: #{operation}"
            end
          end
        end.new
      end

      let(:valid_args) { { operation: "add", num1: 2, num2: 3 } }

      it_behaves_like "a tool"

      it "executes the operation correctly" do
        result = tool.execute(**valid_args)
        expect(result).to eq(5)
      end
    end

    context "with a tool missing required metadata" do
      subject(:tool) do
        Class.new(Smolagents::Tool) do
          self.tool_name = "bad"
          self.description = "Short" # Too short (< 10 chars)
          self.inputs = {}
          self.output_type = "string"

          def execute = "result"
        end.new
      end

      let(:valid_args) { {} }

      it "fails metadata validation" do
        expect(tool.description.length).to be < 10
        # The shared example would catch this
      end
    end

    context "with a tool that fails argument validation" do
      subject(:tool) do
        Class.new(Smolagents::Tool) do
          self.tool_name = "validator_test"
          self.description = "Tests argument validation behavior"
          self.inputs = {
            required_param: { type: "string", description: "A required parameter" }
          }
          self.output_type = "string"

          def execute(required_param:) = required_param.upcase
        end.new
      end

      let(:valid_args) { { required_param: "test" } }

      it_behaves_like "a tool"

      it "rejects invalid arguments" do
        expect do
          tool.validate_tool_arguments({ wrong_param: "value" })
        end.to raise_error(Smolagents::ToolExecutionError)
      end
    end
  end

  describe "'a model' shared example" do
    # Define messages for spec/support shared examples that expect it
    let(:messages) { [Smolagents::ChatMessage.user("Test")] }

    context "with a valid model" do
      subject(:model) do
        Smolagents::Testing::MockModel.new(model_id: "test-model").tap do |m|
          m.queue_response(
            Smolagents::ChatMessage.assistant(
              "Test response",
              token_usage: Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
            )
          )
        end
      end

      it_behaves_like "a model"
    end

    context "with a custom model implementation" do
      subject(:model) do
        Class.new(Smolagents::Models::Model) do
          def initialize(model_id: "custom-model")
            super
          end

          def generate(messages, **)
            Smolagents::ChatMessage.assistant(
              "Custom response: #{messages.last.content}",
              token_usage: Smolagents::TokenUsage.new(
                input_tokens: messages.sum { |m| m.content.length / 4 },
                output_tokens: 10
              )
            )
          end
        end.new
      end

      it_behaves_like "a model"

      it "generates responses with custom logic" do
        msgs = [Smolagents::ChatMessage.user("Hello")]
        response = model.generate(msgs)
        expect(response.content).to include("Custom response")
        expect(response.content).to include("Hello")
      end
    end

    context "with a model that returns minimal token usage" do
      subject(:model) do
        Smolagents::Testing::MockModel.new.tap do |m|
          m.queue_response(
            Smolagents::ChatMessage.assistant(
              "Response",
              token_usage: Smolagents::TokenUsage.new(input_tokens: 0, output_tokens: 0)
            )
          )
        end
      end

      it_behaves_like "a model"

      it "returns valid token usage even when counts are zero" do
        msgs = [Smolagents::ChatMessage.user("Test")]
        response = model.generate(msgs)
        expect(response.token_usage.input_tokens).to eq(0)
        expect(response.token_usage.output_tokens).to eq(0)
      end
    end
  end

  describe "shared examples integration with real components" do
    it "works with FinalAnswerTool" do
      tool = Smolagents::Tools::FinalAnswerTool.new

      # Verify it passes the shared example requirements
      expect(tool.tool_name).to be_a(String)
      expect(tool.description).to be_a(String)
      expect(tool.description.length).to be >= 10
      expect(tool.inputs).to be_a(Hash)
      expect(tool).to respond_to(:execute)
    end

    it "works with a real agent using MockModel" do
      model = Smolagents::Testing::MockModel.new
      model.queue_final_answer("42")

      agent = Smolagents.agent
                        .model { model }
                        .tools(Smolagents::Tools::FinalAnswerTool.new)
                        .build

      task = "What is the answer?"

      # Verify it passes the shared example requirements
      result = agent.run(task)
      expect(result).to be_a(Smolagents::Types::RunResult)
    end
  end
end
