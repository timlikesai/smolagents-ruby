RSpec.describe Smolagents::Testing::MockModelQueue do
  let(:model) { Smolagents::Testing::MockModel.new }
  let(:user_message) { Smolagents::Types::ChatMessage.user("Test message") }

  describe "#queue_response" do
    it "queues a response for next generate call" do
      model.queue_response("test response")

      result = model.generate([user_message])

      expect(result.content).to eq("test response")
    end

    it "accepts custom token usage" do
      model.queue_response("response", input_tokens: 200, output_tokens: 100)

      result = model.generate([user_message])

      expect(result.token_usage.input_tokens).to eq(200)
      expect(result.token_usage.output_tokens).to eq(100)
    end

    it "returns self for chaining" do
      result = model.queue_response("response")

      expect(result).to equal(model)
    end

    it "provides default token usage" do
      model.queue_response("response")

      result = model.generate([user_message])

      expect(result.token_usage).not_to be_nil
      expect(result.token_usage.input_tokens).to eq(50)
      expect(result.token_usage.output_tokens).to eq(25)
    end
  end

  describe "#queue_code_action" do
    it "wraps code in tags" do
      model.queue_code_action("puts 'hello'")

      result = model.generate([user_message])

      expect(result.content).to include("<code>")
      expect(result.content).to include("puts 'hello'")
      expect(result.content).to include("</code>")
    end

    it "returns self for chaining" do
      result = model.queue_code_action("code")

      expect(result).to equal(model)
    end
  end

  describe "#queue_final_answer" do
    it "queues a final_answer() call" do
      model.queue_final_answer("42")

      result = model.generate([user_message])

      expect(result.content).to include("final_answer")
      expect(result.content).to include("42")
    end

    it "wraps answer in code tags" do
      model.queue_final_answer("success")

      result = model.generate([user_message])

      expect(result.content).to include("<code>")
      expect(result.content).to include("</code>")
    end

    it "returns self for chaining" do
      result = model.queue_final_answer("answer")

      expect(result).to equal(model)
    end

    it "properly escapes answer value" do
      model.queue_final_answer("test \"quoted\" string")

      result = model.generate([user_message])

      expect(result.content).to include("final_answer")
    end
  end

  describe "#queue_planning_response" do
    it "queues plain text response" do
      plan = "First do X, then do Y"
      model.queue_planning_response(plan)

      result = model.generate([user_message])

      expect(result.content).to eq(plan)
    end

    it "returns self for chaining" do
      result = model.queue_planning_response("plan")

      expect(result).to equal(model)
    end

    it "does not wrap in code tags" do
      model.queue_planning_response("plain text")

      result = model.generate([user_message])

      expect(result.content).not_to include("<code>")
    end
  end

  describe "#queue_evaluation_done" do
    it "queues evaluation with DONE prefix" do
      model.queue_evaluation_done("answer_value")

      result = model.generate([user_message])

      expect(result.content).to include("DONE:")
      expect(result.content).to include("answer_value")
    end

    it "uses small token values" do
      model.queue_evaluation_done("value")

      result = model.generate([user_message])

      expect(result.token_usage.input_tokens).to eq(20)
      expect(result.token_usage.output_tokens).to eq(10)
    end

    it "returns self for chaining" do
      result = model.queue_evaluation_done("answer")

      expect(result).to equal(model)
    end
  end

  describe "#queue_evaluation_continue" do
    it "queues evaluation with CONTINUE prefix" do
      model.queue_evaluation_continue("More work needed")

      result = model.generate([user_message])

      expect(result.content).to include("CONTINUE:")
      expect(result.content).to include("More work needed")
    end

    it "uses custom reason" do
      model.queue_evaluation_continue("Custom reason")

      result = model.generate([user_message])

      expect(result.content).to include("Custom reason")
    end

    it "provides default reason" do
      model.queue_evaluation_continue

      result = model.generate([user_message])

      expect(result.content).to include("More work needed")
    end

    it "returns self for chaining" do
      result = model.queue_evaluation_continue

      expect(result).to equal(model)
    end
  end

  describe "#queue_evaluation_stuck" do
    it "queues evaluation with STUCK prefix" do
      model.queue_evaluation_stuck("Unable to proceed")

      result = model.generate([user_message])

      expect(result.content).to include("STUCK:")
      expect(result.content).to include("Unable to proceed")
    end

    it "returns self for chaining" do
      result = model.queue_evaluation_stuck("reason")

      expect(result).to equal(model)
    end
  end

  describe "#queue_step_with_eval" do
    it "queues code action followed by evaluation" do
      model.queue_step_with_eval("@result = 42", eval_reason: "Need to verify")

      result1 = model.generate([user_message])
      result2 = model.generate([user_message])

      expect(result1.content).to include("<code>")
      expect(result2.content).to include("CONTINUE:")
      expect(result2.content).to include("Need to verify")
    end

    it "uses default eval reason" do
      model.queue_step_with_eval("code")

      model.generate([user_message])
      result2 = model.generate([user_message])

      expect(result2.content).to include("More work needed")
    end

    it "returns self for chaining" do
      result = model.queue_step_with_eval("code")

      expect(result).to equal(model)
    end
  end

  describe "#queue_tool_call" do
    it "queues a tool call in JSON format" do
      model.queue_tool_call("search", query: "ruby")

      result = model.generate([user_message])

      expect(result).to be_a(Smolagents::Types::ChatMessage)
      expect(result.role).to eq(Smolagents::Types::MessageRole::ASSISTANT)
    end

    it "creates tool call with arguments" do
      model.queue_tool_call("add", a: 5, b: 3)

      result = model.generate([user_message])

      expect(result.tool_calls).not_to be_nil
      expect(result.tool_calls).not_to be_empty
    end

    it "accepts custom tool call id" do
      custom_id = "custom-id-123"
      model.queue_tool_call("search", id: custom_id, query: "test")

      result = model.generate([user_message])

      expect(result.tool_calls[0].id).to eq(custom_id)
    end

    it "auto-generates id if not provided" do
      model.queue_tool_call("search", query: "test")

      result = model.generate([user_message])

      expect(result.tool_calls[0].id).to be_a(String)
      expect(result.tool_calls[0].id).not_to be_empty
    end

    it "returns self for chaining" do
      result = model.queue_tool_call("test")

      expect(result).to equal(model)
    end

    it "includes tool call arguments" do
      model.queue_tool_call("multiply", a: 7, b: 8)

      result = model.generate([user_message])

      tool_call = result.tool_calls[0]
      expect(tool_call.arguments[:a]).to eq(7)
      expect(tool_call.arguments[:b]).to eq(8)
    end
  end

  describe "refinement queue methods" do
    describe "#queue_critique_approved" do
      it "queues LGTM response" do
        model.queue_critique_approved

        result = model.generate([user_message])

        expect(result.content).to eq("LGTM")
      end

      it "returns self for chaining" do
        result = model.queue_critique_approved

        expect(result).to equal(model)
      end
    end

    describe "#queue_critique_issue" do
      it "queues critique with issue and fix" do
        model.queue_critique_issue("Off by one", "Check loop bounds")

        result = model.generate([user_message])

        expect(result.content).to include("ISSUE:")
        expect(result.content).to include("Off by one")
        expect(result.content).to include("FIX:")
        expect(result.content).to include("Check loop bounds")
      end

      it "returns self for chaining" do
        result = model.queue_critique_issue("issue", "fix")

        expect(result).to equal(model)
      end
    end

    describe "#queue_refinement" do
      it "queues refined code response" do
        refined_code = "improved code here"
        model.queue_refinement(refined_code)

        result = model.generate([user_message])

        expect(result.content).to eq(refined_code)
      end

      it "returns self for chaining" do
        result = model.queue_refinement("code")

        expect(result).to equal(model)
      end
    end

    describe "#queue_action_with_refinement" do
      it "queues complete refinement cycle" do
        model.queue_action_with_refinement(
          "initial code",
          issue: "syntax error",
          fix: "use correct syntax",
          refined_code: "fixed code"
        )

        r1 = model.generate([user_message])
        r2 = model.generate([user_message])
        r3 = model.generate([user_message])

        expect(r1.content).to include("initial code")
        expect(r2.content).to include("syntax error")
        expect(r3.content).to eq("fixed code")
      end

      it "returns self for chaining" do
        result = model.queue_action_with_refinement(
          "code",
          issue: "issue",
          fix: "fix",
          refined_code: "refined"
        )

        expect(result).to equal(model)
      end
    end
  end

  describe "method chaining" do
    it "chains multiple queue operations" do
      model.queue_response("step 1")
           .queue_code_action("puts 'code'")
           .queue_final_answer("42")
           .queue_tool_call("search", query: "test")

      expect(model.remaining_responses).to eq(4)
    end

    it "chains evaluation methods" do
      model.queue_evaluation_continue("more work")
           .queue_evaluation_done("final answer")
           .queue_evaluation_stuck("stuck")

      expect(model.remaining_responses).to eq(3)
    end

    it "chains refinement methods" do
      model.queue_critique_approved
           .queue_critique_issue("issue", "fix")
           .queue_refinement("refined")

      expect(model.remaining_responses).to eq(3)
    end
  end

  describe "thread safety" do
    it "handles concurrent queue operations" do
      threads = Array.new(3) do
        Thread.new do
          model.queue_response("response#{Thread.current.object_id}")
        end
      end

      threads.each(&:join)

      expect(model.remaining_responses).to eq(3)
    end
  end
end
