RSpec.describe "Ractor Types" do
  describe Smolagents::RactorTask do
    describe ".create" do
      it "creates a task with generated IDs" do
        task = Smolagents::RactorTask.create(
          agent_name: "researcher",
          prompt: "Research topic X"
        )

        expect(task.task_id).to match(/\A[0-9a-f-]{36}\z/)
        expect(task.trace_id).to match(/\A[0-9a-f-]{36}\z/)
        expect(task.agent_name).to eq("researcher")
        expect(task.prompt).to eq("Research topic X")
        expect(task.timeout).to eq(30)
        expect(task.config).to eq({})
      end

      it "accepts custom config and timeout" do
        task = Smolagents::RactorTask.create(
          agent_name: "analyzer",
          prompt: "Analyze data",
          config: { max_steps: 5 },
          timeout: 60,
          trace_id: "custom-trace"
        )

        expect(task.config).to eq({ max_steps: 5 })
        expect(task.timeout).to eq(60)
        expect(task.trace_id).to eq("custom-trace")
      end

      it "deep freezes config" do
        task = Smolagents::RactorTask.create(
          agent_name: "agent",
          prompt: "task",
          config: { nested: { value: "test" } }
        )

        expect(task.config).to be_frozen
        expect(task.config[:nested]).to be_frozen
      end
    end

    it "supports pattern matching" do
      task = Smolagents::RactorTask.create(agent_name: "test", prompt: "hello")

      matched = case task
                in Smolagents::RactorTask[agent_name: "test", prompt:]
                  prompt
                else
                  nil
                end

      expect(matched).to eq("hello")
    end
  end

  describe Smolagents::RactorSuccess do
    let(:mock_result) do
      double("RunResult",
             output: "Result output",
             steps: [1, 2, 3],
             token_usage: Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50))
    end

    describe ".from_result" do
      it "creates success from run result" do
        success = Smolagents::RactorSuccess.from_result(
          task_id: "task-123",
          run_result: mock_result,
          duration: 1.5,
          trace_id: "trace-456"
        )

        expect(success.task_id).to eq("task-123")
        expect(success.output).to eq("Result output")
        expect(success.steps_taken).to eq(3)
        expect(success.token_usage.total_tokens).to eq(150)
        expect(success.duration).to eq(1.5)
        expect(success.trace_id).to eq("trace-456")
      end
    end

    it "reports success correctly" do
      success = Smolagents::RactorSuccess.from_result(
        task_id: "id", run_result: mock_result, duration: 1.0, trace_id: "t"
      )

      expect(success).to be_success
      expect(success).not_to be_failure
    end

    it "supports pattern matching" do
      success = Smolagents::RactorSuccess.from_result(
        task_id: "id", run_result: mock_result, duration: 1.0, trace_id: "t"
      )

      matched = case success
                in Smolagents::RactorSuccess[output:, success: true]
                  output
                else
                  nil
                end

      expect(matched).to eq("Result output")
    end
  end

  describe Smolagents::RactorFailure do
    describe ".from_exception" do
      it "creates failure from exception" do
        error = RuntimeError.new("Something went wrong")

        failure = Smolagents::RactorFailure.from_exception(
          task_id: "task-123",
          error: error,
          trace_id: "trace-456",
          steps_taken: 2,
          duration: 0.5
        )

        expect(failure.task_id).to eq("task-123")
        expect(failure.error_class).to eq("RuntimeError")
        expect(failure.error_message).to eq("Something went wrong")
        expect(failure.steps_taken).to eq(2)
        expect(failure.duration).to eq(0.5)
        expect(failure.trace_id).to eq("trace-456")
      end
    end

    it "reports failure correctly" do
      failure = Smolagents::RactorFailure.from_exception(
        task_id: "id", error: StandardError.new("err"), trace_id: "t"
      )

      expect(failure).to be_failure
      expect(failure).not_to be_success
    end

    it "supports pattern matching" do
      failure = Smolagents::RactorFailure.from_exception(
        task_id: "id", error: ArgumentError.new("bad arg"), trace_id: "t"
      )

      matched = case failure
                in Smolagents::RactorFailure[error_class: "ArgumentError", error_message:]
                  error_message
                else
                  nil
                end

      expect(matched).to eq("bad arg")
    end
  end

  describe Smolagents::RactorMessage do
    describe ".task" do
      it "wraps a task" do
        task = Smolagents::RactorTask.create(agent_name: "a", prompt: "p")
        message = Smolagents::RactorMessage.task(task)

        expect(message).to be_task
        expect(message).not_to be_result
        expect(message.payload).to eq(task)
      end
    end

    describe ".result" do
      it "wraps a result" do
        mock_result = double("RunResult", output: "out", steps: [], token_usage: nil)
        success = Smolagents::RactorSuccess.from_result(
          task_id: "id", run_result: mock_result, duration: 1.0, trace_id: "t"
        )
        message = Smolagents::RactorMessage.result(success)

        expect(message).to be_result
        expect(message).not_to be_task
        expect(message.payload).to eq(success)
      end
    end

    it "supports pattern matching" do
      task = Smolagents::RactorTask.create(agent_name: "test", prompt: "hello")
      message = Smolagents::RactorMessage.task(task)

      matched = case message
                in Smolagents::RactorMessage[type: :task, payload:]
                  payload.agent_name
                else
                  nil
                end

      expect(matched).to eq("test")
    end
  end

  describe Smolagents::OrchestratorResult do
    let(:mock_result) { double("RunResult", output: "out", steps: [1], token_usage: Smolagents::TokenUsage.new(input_tokens: 50, output_tokens: 25)) }

    let(:success1) { Smolagents::RactorSuccess.from_result(task_id: "1", run_result: mock_result, duration: 1.0, trace_id: "t1") }
    let(:success2) { Smolagents::RactorSuccess.from_result(task_id: "2", run_result: mock_result, duration: 1.5, trace_id: "t2") }
    let(:failure1) { Smolagents::RactorFailure.from_exception(task_id: "3", error: RuntimeError.new("fail"), trace_id: "t3") }

    describe ".create" do
      it "creates result with frozen arrays" do
        result = Smolagents::OrchestratorResult.create(
          succeeded: [success1, success2],
          failed: [failure1],
          duration: 2.5
        )

        expect(result.succeeded).to be_frozen
        expect(result.failed).to be_frozen
        expect(result.duration).to eq(2.5)
      end
    end

    describe "aggregate methods" do
      it "reports success/failure counts" do
        result = Smolagents::OrchestratorResult.create(
          succeeded: [success1, success2],
          failed: [failure1],
          duration: 2.0
        )

        expect(result.success_count).to eq(2)
        expect(result.failure_count).to eq(1)
        expect(result.total_count).to eq(3)
        expect(result).not_to be_all_success
        expect(result).to be_any_success
      end

      it "reports all_success when no failures" do
        result = Smolagents::OrchestratorResult.create(
          succeeded: [success1],
          failed: [],
          duration: 1.0
        )

        expect(result).to be_all_success
      end

      it "calculates total tokens" do
        result = Smolagents::OrchestratorResult.create(
          succeeded: [success1, success2],
          failed: [],
          duration: 2.0
        )

        expect(result.total_tokens).to eq(150) # (50+25) * 2
      end

      it "calculates total steps" do
        result = Smolagents::OrchestratorResult.create(
          succeeded: [success1, success2],
          failed: [],
          duration: 2.0
        )

        expect(result.total_steps).to eq(2) # 1 + 1
      end

      it "extracts outputs and errors" do
        result = Smolagents::OrchestratorResult.create(
          succeeded: [success1],
          failed: [failure1],
          duration: 2.0
        )

        expect(result.outputs).to eq(["out"])
        expect(result.errors).to eq(["fail"])
      end
    end

    it "supports pattern matching" do
      result = Smolagents::OrchestratorResult.create(
        succeeded: [success1, success2],
        failed: [],
        duration: 2.0
      )

      matched = case result
                in Smolagents::OrchestratorResult[all_success: true, success_count:]
                  success_count
                else
                  nil
                end

      expect(matched).to eq(2)
    end
  end
end
