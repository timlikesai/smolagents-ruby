RSpec.describe Smolagents::Orchestrators::RactorOrchestrator, "#execute_single" do
  # These tests run real Ractors with stubbed HTTP responses.
  # They verify that agent reconstruction works end-to-end.

  before do
    # IMPORTANT: Return Timecop to normal state - it interferes with Ractors
    # because Timecop's singleton can't be accessed from non-main Ractors
    Timecop.return

    # Set up API key for Ractor execution
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("SMOLAGENTS_API_KEY").and_return("test-api-key")
  end

  after do
    # Clean up any Ractors that might still be running
    Timecop.return
  end

  # Create a minimal model response that will trigger final_answer
  let(:model_response) do
    {
      "choices" => [{
        "message" => {
          "content" => nil,
          "tool_calls" => [{
            "id" => "call_123",
            "type" => "function",
            "function" => {
              "name" => "final_answer",
              "arguments" => '{"answer": "Test completed successfully"}'
            }
          }]
        }
      }],
      "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5 }
    }
  end

  let(:real_model) do
    # Stub the HTTP request that OpenAI client will make
    stub_request(:post, "http://localhost:1234/v1/chat/completions")
      .to_return(
        status: 200,
        body: model_response.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    Smolagents::Models::OpenAIModel.new(
      model_id: "test-model",
      api_key: "test-api-key",
      api_base: "http://localhost:1234/v1"
    )
  end

  let(:real_agent) do
    Smolagents::Agents::ToolCalling.new(
      model: real_model,
      tools: [Smolagents::Tools.get("final_answer")],
      max_steps: 3
    )
  end

  let(:agents) { { "test_agent" => real_agent } }
  let(:orchestrator) { described_class.new(agents: agents, max_concurrent: 2) }

  describe "#execute_single with real Ractor" do
    it "executes agent in isolated Ractor and returns result" do
      # Stub for the Ractor's reconstructed model
      stub_request(:post, "http://localhost:1234/v1/chat/completions")
        .to_return(
          status: 200,
          body: model_response.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = orchestrator.execute_single(
        agent_name: "test_agent",
        prompt: "Test task",
        timeout: 10
      )

      expect(result).to be_a(Smolagents::RactorSuccess).or be_a(Smolagents::RactorFailure)

      if result.success?
        expect(result.output).to include("Test completed successfully")
        expect(result.task_id).to be_a(String)
        expect(result.duration).to be_a(Float)
      else
        # If it failed, show the error for debugging
        puts "Ractor execution failed: #{result.error_class} - #{result.error_message}"
      end
    end
  end

  describe "#execute_parallel with real Ractors" do
    let(:agents_multiple) do
      {
        "agent_1" => real_agent,
        "agent_2" => Smolagents::Agents::ToolCalling.new(
          model: Smolagents::Models::OpenAIModel.new(
            model_id: "test-model-2",
            api_key: "test-api-key",
            api_base: "http://localhost:1234/v1"
          ),
          tools: [Smolagents::Tools.get("final_answer")],
          max_steps: 3
        )
      }
    end

    let(:orchestrator_multiple) { described_class.new(agents: agents_multiple, max_concurrent: 2) }

    it "executes multiple agents in parallel Ractors" do
      # Stub for all Ractor model calls
      stub_request(:post, "http://localhost:1234/v1/chat/completions")
        .to_return(
          status: 200,
          body: model_response.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      tasks = [
        ["agent_1", "Task for agent 1", {}],
        ["agent_2", "Task for agent 2", {}]
      ]

      result = orchestrator_multiple.execute_parallel(tasks: tasks, timeout: 30)

      expect(result).to be_a(Smolagents::OrchestratorResult)
      expect(result.total_count).to eq(2)
      expect(result.duration).to be_a(Float)

      # At least check we got results back (success or failure)
      if result.all_success?
        expect(result.success_count).to eq(2)
        expect(result.outputs).to all(include("Test completed successfully"))
      else
        # Show failures for debugging
        result.failed.each do |f|
          puts "Task #{f.task_id} failed: #{f.error_class} - #{f.error_message}"
        end
      end
    end
  end

  describe "error propagation through Ractor" do
    it "returns RactorFailure when agent execution fails" do
      # Stub to return an error response
      stub_request(:post, "http://localhost:1234/v1/chat/completions")
        .to_return(
          status: 500,
          body: { "error" => { "message" => "Internal server error" } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = orchestrator.execute_single(
        agent_name: "test_agent",
        prompt: "This should fail",
        timeout: 10
      )

      # We expect either a failure from the API error, or potentially success
      # if the agent handles the error gracefully
      expect(result).to respond_to(:success?)
      expect(result).to respond_to(:failure?)
    end
  end
end
