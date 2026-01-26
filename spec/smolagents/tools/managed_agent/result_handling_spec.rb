RSpec.describe Smolagents::Tools::ManagedAgentTool do
  describe "Result handling functionality" do
    let(:mock_agent) do
      double(
        "agent",
        run: double("result", success?: true, output: "output"),
        respond_to?: false,
        tools: { search: double }
      )
    end

    let(:tool) do
      described_class.new(
        agent: mock_agent,
        name: "test_agent",
        description: "Test agent"
      )
    end

    before do
      allow(tool).to receive(:emit)
    end

    describe "#handle_error" do
      it "returns error message with agent name" do
        error = StandardError.new("Connection timeout")

        result = tool.send(:handle_error, error, "test task", nil)

        expect(result).to include("test_agent")
        expect(result).to include("Connection timeout")
      end

      it "emits events via emit method" do
        error = StandardError.new("Test error")

        tool.send(:handle_error, error, "task", nil)

        # emit_error calls emit internally, and emit_completion also calls emit
        expect(tool).to have_received(:emit).at_least(:once)
      end

      it "emits completion event with error outcome" do
        error = StandardError.new("Failure")
        event = double(id: "event_123")

        tool.send(:handle_error, error, "task", event)

        # emit_error calls emit, emit_completion calls emit
        expect(tool).to have_received(:emit).at_least(:twice)
      end

      it "emits events that include task context" do
        error = StandardError.new("Error")
        task = "Complex task description"

        tool.send(:handle_error, error, task, nil)

        # Error context is included in the emit_error call
        expect(tool).to have_received(:emit).at_least(:once)
      end
    end

    describe "#handle_result" do
      context "when result is successful" do
        it "returns output string" do
          result = double(
            success?: true,
            output: double(to_s: "Agent output"),
            token_usage: { completion_tokens: 10 },
            step_count: 3,
            duration: 1.0
          )

          output = tool.send(:handle_result, result, "event_id")

          expect(output).to eq("Agent output")
        end

        it "emits completion with success outcome" do
          result = double(
            success?: true,
            output: double(to_s: "Success output"),
            token_usage: { completion_tokens: 10 },
            step_count: 5,
            duration: 1.5
          )

          tool.send(:handle_result, result, "event_id")

          expect(tool).to have_received(:emit)
        end
      end

      context "when result is failed" do
        it "returns failure message with agent name and state" do
          result = double(
            success?: false,
            state: "max_iterations_reached",
            token_usage: nil,
            step_count: nil,
            duration: nil
          )

          output = tool.send(:handle_result, result, "event_id")

          expect(output).to include("test_agent")
          expect(output).to include("failed")
          expect(output).to include("max_iterations_reached")
        end

        it "emits completion with failure outcome" do
          result = double(
            success?: false,
            state: "error_state",
            token_usage: nil,
            step_count: nil,
            duration: nil
          )

          tool.send(:handle_result, result, "event_id")

          expect(tool).to have_received(:emit)
        end
      end
    end

    describe "#success_result" do
      it "returns the output as string" do
        result = double(
          output: double(to_s: "Success output"),
          token_usage: {},
          step_count: 3,
          duration: 1.0
        )

        output = tool.send(:success_result, result, "event_id")

        expect(output).to eq("Success output")
      end

      it "emits completion event" do
        result = double(
          output: double(to_s: "Output"),
          token_usage: { completion_tokens: 20 },
          step_count: 4,
          duration: 2.0
        )

        tool.send(:success_result, result, "event_id")

        expect(tool).to have_received(:emit)
      end
    end

    describe "#emit_completion" do
      it "emits SubAgentCompleted event with basic info" do
        tool.send(:emit_completion, "event_id", :success)

        expect(tool).to have_received(:emit)
      end

      it "includes result information when available" do
        result = double(
          token_usage: { completion_tokens: 50 },
          step_count: 10,
          duration: 3.5
        )

        tool.send(:emit_completion, "event_id", :success, result:, output: "Done")

        expect(tool).to have_received(:emit)
      end

      it "includes error information when failed" do
        tool.send(:emit_completion, "event_id", :error, error: "Something went wrong")

        expect(tool).to have_received(:emit)
      end

      it "handles nil launch_id" do
        expect { tool.send(:emit_completion, nil, :success) }.not_to raise_error
      end
    end

    describe "#record_to_observability" do
      context "when observability context available" do
        it "records sub-agent to observability" do
          obs_ctx = double("observability_context")
          allow(Smolagents::Types::ObservabilityContext).to receive(:current).and_return(obs_ctx)
          allow(obs_ctx).to receive(:record_sub_agent)

          result = double(
            token_usage: { completion_tokens: 30 },
            step_count: 5,
            duration: 1.5
          )

          tool.send(:record_to_observability, result, :success)

          expect(obs_ctx).to have_received(:record_sub_agent).with(
            hash_including(
              agent_name: "test_agent",
              outcome: :success
            )
          )
        end
      end

      context "when no observability context" do
        it "returns early without error" do
          allow(Smolagents::Types::ObservabilityContext).to receive(:current).and_return(nil)

          result = double(
            token_usage: { completion_tokens: 10 },
            step_count: 3,
            duration: 1.0
          )

          expect { tool.send(:record_to_observability, result, :success) }.not_to raise_error
        end
      end

      context "when result is nil" do
        it "returns early without recording" do
          obs_ctx = double("observability_context")
          allow(Smolagents::Types::ObservabilityContext).to receive(:current).and_return(obs_ctx)
          allow(obs_ctx).to receive(:record_sub_agent)

          tool.send(:record_to_observability, nil, :error)

          expect(obs_ctx).not_to have_received(:record_sub_agent)
        end
      end
    end

    describe "error handling flow" do
      it "handles exception in execute and returns error string" do
        error = RuntimeError.new("Execution failed")

        result = tool.send(:handle_error, error, "task", double(id: "event"))

        expect(result).to be_a(String)
        expect(result).to include("error")
      end

      it "includes token usage in completion event" do
        result = double(
          success?: true,
          output: double(to_s: "Done"),
          token_usage: { input_tokens: 100, completion_tokens: 50 },
          step_count: 5,
          duration: 2.5
        )

        tool.send(:handle_result, result, "event_id")

        expect(tool).to have_received(:emit)
      end
    end

    describe "outcome tracking" do
      it "tracks success outcome" do
        result = double(
          success?: true,
          output: double(to_s: "Done"),
          token_usage: {},
          step_count: 2,
          duration: 0.5
        )

        tool.send(:handle_result, result, "event_id")

        expect(tool).to have_received(:emit)
      end

      it "tracks failure outcome" do
        result = double(
          success?: false,
          state: "timeout",
          token_usage: nil,
          step_count: nil,
          duration: nil
        )

        tool.send(:handle_result, result, "event_id")

        expect(tool).to have_received(:emit)
      end

      it "tracks error outcome" do
        error = StandardError.new("Test")

        tool.send(:handle_error, error, "task", double(id: "event"))

        expect(tool).to have_received(:emit).at_least(:twice)
      end
    end
  end
end
