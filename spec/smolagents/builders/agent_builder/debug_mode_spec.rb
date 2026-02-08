RSpec.describe "AgentBuilder#debug", type: :integration do
  let(:model) { build_mock_model(responses: ['final_answer(answer: "done")']) }

  describe ".debug" do
    it "returns a new builder with debug mode enabled" do
      builder = Smolagents.agent.debug
      expect(builder.config[:debug_mode]).to be true
      expect(builder.config[:logging_level]).to eq(:debug)
    end

    it "is chainable with other builder methods" do
      builder = Smolagents.agent.model { model }.debug.max_steps(5)
      expect(builder.config[:debug_mode]).to be true
      expect(builder.config[:max_steps]).to eq(5)
    end
  end

  describe "built agent with debug mode" do
    let(:agent) do
      Smolagents.agent
                .model { model }
                .debug
                .build
    end

    it "includes stats tracking" do
      expect(agent).to respond_to(:stats)
      expect(agent.stats).to be_a(Smolagents::Types::AgentStats)
    end

    it "includes failure capture" do
      expect(agent).to respond_to(:last_failures)
      expect(agent).to respond_to(:last_failure)
      expect(agent).to respond_to(:failure_count)
    end

    it "has a debug-level logger" do
      expect(agent.logger).not_to be_nil
    end
  end
end
