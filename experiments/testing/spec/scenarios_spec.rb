RSpec.describe Smolagents::Testing::Scenarios do
  describe ".simple_answer" do
    it "returns model and expected answer" do
      model, answer = described_class.simple_answer("42")
      expect(model).to be_a(Smolagents::Testing::MockModel)
      expect(answer).to eq("42")
    end

    it "queues one response" do
      model, = described_class.simple_answer
      expect(model.remaining_responses).to eq(1)
    end

    it "uses default answer of 42" do
      _, answer = described_class.simple_answer
      expect(answer).to eq("42")
    end
  end

  describe ".multi_step" do
    it "queues correct number of responses" do
      model = described_class.multi_step(steps: 3)
      expect(model.remaining_responses).to eq(3)
    end

    it "ends with final answer" do
      model = described_class.multi_step(steps: 2, answer: "done")
      msg = [Smolagents::Types::ChatMessage.user("test")]

      # Consume intermediate step
      model.generate(msg)
      # Get final answer
      response = model.generate(msg)
      expect(response.content).to include("final_answer")
    end
  end

  describe ".with_tool_calls" do
    it "queues tool calls plus final answer" do
      model = described_class.with_tool_calls([
                                                { tool: :search, args: "query: 'test'" },
                                                { tool: :fetch }
                                              ])
      expect(model.remaining_responses).to eq(3)
    end

    it "generates correct tool call code" do
      model = described_class.with_tool_calls([{ tool: :search, args: "query: 'test'" }])
      response = model.generate([Smolagents::Types::ChatMessage.user("test")])
      expect(response.content).to include("search(query: 'test')")
    end
  end

  describe ".retry_success" do
    it "queues failures plus success" do
      model = described_class.retry_success(failures: 2)
      expect(model.remaining_responses).to eq(3)
    end

    it "raises errors for failures" do
      model = described_class.retry_success(failures: 2, error: RuntimeError)
      msg = [Smolagents::Types::ChatMessage.user("test")]

      expect { model.generate(msg) }.to raise_error(RuntimeError)
      expect { model.generate(msg) }.to raise_error(RuntimeError)

      # Third call succeeds
      response = model.generate(msg)
      expect(response.content).to include("final_answer")
    end
  end

  describe ".with_evaluation" do
    it "queues work + evaluation cycles" do
      model = described_class.with_evaluation(steps: 2)
      # 2 steps * (1 action + 1 eval) + 1 final + 1 eval_done = 6
      expect(model.remaining_responses).to eq(6)
    end
  end

  describe ".with_planning" do
    it "starts with planning response" do
      model = described_class.with_planning(plan: "My plan")
      response = model.generate([Smolagents::Types::ChatMessage.user("test")])
      expect(response.content).to eq("My plan")
    end

    it "queues planning + steps + final" do
      model = described_class.with_planning(steps: 2)
      expect(model.remaining_responses).to eq(4) # 1 plan + 2 steps + 1 final
    end
  end

  describe ".stuck_agent" do
    it "queues repetitions plus final answer" do
      model = described_class.stuck_agent(repetitions: 3)
      expect(model.remaining_responses).to eq(4)
    end

    it "generates same action multiple times" do
      model = described_class.stuck_agent(repetitions: 2)
      msg = [Smolagents::Types::ChatMessage.user("test")]

      r1 = model.generate(msg)
      r2 = model.generate(msg)

      expect(r1.content).to eq(r2.content)
    end
  end

  describe ".with_refinement" do
    it "queues refinement cycle" do
      model = described_class.with_refinement(iterations: 1)
      # 1 initial + 1 critique + 1 refine + 1 approved + 1 final = 5
      expect(model.remaining_responses).to eq(5)
    end
  end
end

RSpec.describe Smolagents::Testing, ".scenario" do
  it "delegates to Scenarios" do
    model, answer = described_class.scenario(:simple_answer, "test")
    expect(model).to be_a(Smolagents::Testing::MockModel)
    expect(answer).to eq("test")
  end

  it "accepts keyword arguments" do
    model = described_class.scenario(:multi_step, steps: 5)
    expect(model.remaining_responses).to eq(5)
  end

  it "raises for unknown scenario" do
    expect do
      described_class.scenario(:unknown)
    end.to raise_error(ArgumentError, /Unknown scenario/)
  end
end
