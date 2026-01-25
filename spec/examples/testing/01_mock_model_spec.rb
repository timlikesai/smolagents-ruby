require "spec_helper"
require_relative "../../../examples/testing/01_mock_model"

RSpec.describe "Example: MockModel Testing", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "test_simple_answer?" do
    it "returns true when agent produces correct answer" do
      expect(test_simple_answer?).to be true
    end
  end

  describe "test_tool_execution" do
    it "executes tool and returns result" do
      model = mock_model do |m|
        m.queue_code_action("final_answer(answer: add(a: 10, b: 32))")
      end

      result = test_tool_execution(model)

      expect(result.output).to eq(42)
      expect(result.state).to eq(:success)
    end
  end

  describe "test_multi_step" do
    it "executes multiple tools via nested calls" do
      model = mock_model do |m|
        # Nested tool calls in single expression - simpler for testing
        m.queue_code_action("final_answer(answer: format(data: fetch(id: 42)))")
      end

      result = test_multi_step(model)

      expect(result.output).to eq("Name: Item 42")
      expect(result.state).to eq(:success)
    end
  end

  describe "verify_model_was_called" do
    it "tracks model call statistics" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = Smolagents.agent.model { model }.build

      agent.run("Test task")
      stats = verify_model_was_called(model)

      expect(stats[:total_calls]).to eq(1)
      expect(stats[:messages_in_first_call]).to be >= 2 # system + user
      expect(stats[:remaining_responses]).to eq(0)
    end
  end

  describe "test_error_recovery" do
    it "handles errors gracefully" do
      model = mock_model do |m|
        m.queue_code_action("undefined_variable_xyz") # This will error
        m.queue_evaluation_continue
        m.queue_final_answer("Recovered from error")
      end

      result = test_error_recovery(model)

      expect(result.output).to eq("Recovered from error")
      expect(result.state).to eq(:success)
    end
  end

  describe "MockModel core features" do
    describe "queue methods" do
      it "queue_final_answer wraps in final_answer call" do
        model = Smolagents::Testing::MockModel.new
        model.queue_final_answer("the answer")

        response = model.generate([])

        expect(response.content).to include("final_answer")
        expect(response.content).to include("the answer")
      end

      it "queue_code_action wraps in code tags" do
        model = Smolagents::Testing::MockModel.new
        model.queue_code_action("x = 42")

        response = model.generate([])

        expect(response.content).to include("<code>")
        expect(response.content).to include("x = 42")
      end

      it "queue_evaluation_continue generates CONTINUE response" do
        model = Smolagents::Testing::MockModel.new
        model.queue_evaluation_continue

        response = model.generate([])

        expect(response.content).to include("CONTINUE")
      end

      it "queue_evaluation_done generates DONE response" do
        model = Smolagents::Testing::MockModel.new
        model.queue_evaluation_done("42")

        response = model.generate([])

        expect(response.content).to include("DONE")
        expect(response.content).to include("42")
      end
    end

    describe "call recording" do
      it "records each generate call" do
        model = mock_model do |m|
          m.queue_final_answer("one")
          m.queue_final_answer("two")
        end

        model.generate([{ role: :user, content: "first" }])
        model.generate([{ role: :user, content: "second" }])

        expect(model.call_count).to eq(2)
        expect(model.calls.size).to eq(2)
      end

      it "provides last_call accessor" do
        model = mock_model do |m|
          m.queue_final_answer("response")
        end

        model.generate([Smolagents::Types::ChatMessage.user("my message")])

        expect(model.last_call.messages.last.content).to eq("my message")
      end

      it "tracks remaining responses" do
        model = mock_model do |m|
          m.queue_final_answer("one")
          m.queue_final_answer("two")
          m.queue_final_answer("three")
        end

        expect(model.remaining_responses).to eq(3)
        model.generate([])
        expect(model.remaining_responses).to eq(2)
      end
    end

    describe "be_exhausted matcher" do
      it "passes when all responses consumed" do
        model = mock_model { |m| m.queue_final_answer("done") }
        model.generate([])

        expect(model).to be_exhausted
      end

      it "fails when responses remain" do
        model = mock_model do |m|
          m.queue_final_answer("one")
          m.queue_final_answer("two")
        end
        model.generate([])

        expect(model).not_to be_exhausted
      end
    end

    describe "reset!" do
      it "clears all state" do
        model = mock_model do |m|
          m.queue_final_answer("old")
        end
        model.generate([])

        model.reset!
        model.queue_final_answer("new")

        expect(model.call_count).to eq(0)
        expect(model.remaining_responses).to eq(1)
      end
    end
  end

  describe "helper methods from ModelHelpers" do
    it "mock_model creates configured model" do
      model = mock_model do |m|
        m.queue_final_answer("configured")
      end

      expect(model).to be_a(Smolagents::Testing::MockModel)
      expect(model.remaining_responses).to eq(1)
    end

    it "mock_single_step is shorthand" do
      model = mock_single_step("quick answer")

      response = model.generate([])
      expect(response.content).to include("quick answer")
    end

    it "mock_model_with_planning sets up planning scenario" do
      model = mock_model_with_planning(plan: "Step 1: Think", answer: "42")

      # First call returns planning response
      plan_response = model.generate([])
      expect(plan_response.content).to include("Step 1")

      # Second call returns answer
      answer_response = model.generate([])
      expect(answer_response.content).to include("42")
    end
  end

  describe "fluent API aliases" do
    it "returns is alias for queue_response" do
      model = Smolagents::Testing::MockModel.new
      model.returns("raw response")

      expect(model.generate([]).content).to eq("raw response")
    end

    it "returns_code is alias for queue_code_action" do
      model = Smolagents::Testing::MockModel.new
      model.returns_code("x = 1")

      expect(model.generate([]).content).to include("<code>")
    end

    it "answers is alias for queue_final_answer" do
      model = Smolagents::Testing::MockModel.new
      model.answers("the answer")

      expect(model.generate([]).content).to include("final_answer")
    end

    it "supports chaining" do
      model = Smolagents::Testing::MockModel.new
                                            .returns_code("step1 = 1")
                                            .queue_evaluation_continue
                                            .answers("done")

      expect(model.remaining_responses).to eq(3)
    end
  end
end
