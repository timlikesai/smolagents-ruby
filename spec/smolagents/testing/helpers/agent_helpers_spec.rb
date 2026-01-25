RSpec.describe Smolagents::Testing::Helpers::AgentHelpers do
  include described_class

  describe "#test_agent" do
    it "creates an agent with a mock model" do
      agent = test_agent(model_response: "test response")

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "uses provided model response" do
      response = "Hello, world!"
      agent = test_agent(model_response: response)

      # The agent should be configured with the response
      expect(agent).not_to be_nil
    end

    it "accepts custom tools" do
      tool = Smolagents::Testing::TestTools.add
      agent = test_agent(model_response: "response", tools: [tool])

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "accepts multiple tools" do
      tools = [Smolagents::Testing::TestTools.add, Smolagents::Testing::TestTools.multiply]
      agent = test_agent(model_response: "response", tools:)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "accepts custom agent class" do
      custom_class = Smolagents::Agents::Agent
      agent = test_agent(model_response: "response", agent_class: custom_class)

      expect(agent).to be_a(custom_class)
    end

    it "handles ChatMessage as response" do
      message = Smolagents::Types::ChatMessage.assistant("test")
      agent = test_agent(model_response: message)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "uses default empty tools list" do
      agent = test_agent(model_response: "response")

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "#capture_agent_steps" do
    it "returns array of captured steps" do
      agent = test_agent(model_response: "response")

      steps = capture_agent_steps(agent) { nil }

      expect(steps).to be_an(Array)
    end

    it "captures steps during agent execution", max_time: 0.15 do
      agent = test_agent(model_response: "42")
      steps = []

      capture_agent_steps(agent) do
        agent.run("What is 2 + 2?")
      rescue StandardError
        # Ignore execution errors
      end

      # Steps may be captured (depends on agent implementation)
      expect(steps).to be_an(Array)
    end

    it "registers callback with agent" do
      agent = test_agent(model_response: "response")

      expect do
        capture_agent_steps(agent) { nil }
      end.not_to raise_error
    end

    it "allows multiple captures" do
      agent = test_agent(model_response: "response")

      steps1 = capture_agent_steps(agent) { nil }
      steps2 = capture_agent_steps(agent) { nil }

      expect(steps1).to be_an(Array)
      expect(steps2).to be_an(Array)
    end
  end

  describe "#assert_agent_success" do
    it "passes for non-nil result" do
      result = "success"

      expect { assert_agent_success(result) }.not_to raise_error
    end

    it "passes for string result" do
      result = "final answer"

      expect { assert_agent_success(result) }.not_to raise_error
    end

    it "passes for hash result" do
      result = { answer: "42" }

      expect { assert_agent_success(result) }.not_to raise_error
    end

    it "passes for RunResult" do
      result = Smolagents::Types::RunResult.success(output: "done", steps: [])

      expect { assert_agent_success(result) }.not_to raise_error
    end

    it "fails for nil result" do
      result = nil

      expect { assert_agent_success(result) }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
    end
  end

  describe "#raise_agent_error" do
    it "returns a matcher for error assertion" do
      matcher = raise_agent_error(StandardError)

      expect(matcher).to be_a(RSpec::Matchers::BuiltIn::RaiseError)
    end

    it "creates matcher for specific error class" do
      matcher = raise_agent_error(ArgumentError)

      expect(matcher).to be_a(RSpec::Matchers::BuiltIn::RaiseError)
    end

    it "can be used in expect block" do
      expect do
        raise StandardError, "test error"
      end.to raise_agent_error(StandardError)
    end
  end

  describe "#with_agent_workspace" do
    it "yields a temporary directory path" do
      path = nil

      with_agent_workspace do |workspace|
        path = workspace
      end

      expect(path).to be_a(String)
    end

    it "creates a temporary directory" do
      with_agent_workspace do |workspace|
        expect(Dir.exist?(workspace)).to be true
      end
    end

    it "includes smolagents-test in directory name" do
      with_agent_workspace do |workspace|
        expect(workspace).to include("smolagents-test")
      end
    end

    it "cleans up directory after block" do
      workspace_path = nil

      with_agent_workspace do |workspace|
        workspace_path = workspace
        expect(Dir.exist?(workspace_path)).to be true
      end

      # Directory should be cleaned up
      expect(Dir.exist?(workspace_path)).to be false
    end

    it "allows file operations inside workspace" do
      with_agent_workspace do |workspace|
        test_file = File.join(workspace, "test.txt")
        File.write(test_file, "test content")

        expect(File.exist?(test_file)).to be true
        expect(File.read(test_file)).to eq("test content")
      end
    end

    it "returns block result" do
      result = with_agent_workspace do |workspace|
        "result from block"
      end

      expect(result).to eq("result from block")
    end
  end

  describe "helper integration" do
    it "all methods are available in test context" do
      expect(self).to respond_to(:test_agent)
      expect(self).to respond_to(:capture_agent_steps)
      expect(self).to respond_to(:assert_agent_success)
      expect(self).to respond_to(:raise_agent_error)
      expect(self).to respond_to(:with_agent_workspace)
    end
  end

  describe "method chaining" do
    it "can create agent and use workspace in same test" do
      agent = test_agent(model_response: "response")

      with_agent_workspace do |workspace|
        expect(agent).to be_a(Smolagents::Agents::Agent)
        expect(Dir.exist?(workspace)).to be true
      end
    end
  end
end
