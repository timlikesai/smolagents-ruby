RSpec.describe "Ractor Types", type: :feature do
  describe Smolagents::RactorTask do
    let(:instance) { described_class.create(agent_name: "test", prompt: "hello") }

    it_behaves_like "a frozen type"
    it_behaves_like "a pattern matchable type"

    describe ".create" do
      it "creates a task with generated IDs" do
        task = described_class.create(
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
        task = described_class.create(
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
        task = described_class.create(
          agent_name: "agent",
          prompt: "task",
          config: { nested: { value: "test" } }
        )

        expect(task.config).to be_frozen
        expect(task.config[:nested]).to be_frozen
      end
    end

    it "supports pattern matching" do
      task = described_class.create(agent_name: "test", prompt: "hello")

      matched = case task
                in Smolagents::RactorTask[agent_name: "test", prompt:] # rubocop:disable RSpec/DescribedClass -- pattern matching requires constants
                  prompt
                else
                  nil
                end

      expect(matched).to eq("hello")
    end
  end

  describe Smolagents::RactorSuccess do
    let(:mock_result) do
      # rubocop:disable RSpec/VerifiedDoubles -- duck-typed RunResult interface
      double("RunResult",
             output: "Result output",
             steps: [1, 2, 3],
             token_usage: Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50))
      # rubocop:enable RSpec/VerifiedDoubles
    end

    let(:instance) { described_class.from_result(task_id: "id", run_result: mock_result, duration: 1.0, trace_id: "t") }

    it_behaves_like "a frozen type"
    it_behaves_like "a pattern matchable type"

    describe ".from_result" do
      it "creates success from run result" do
        success = described_class.from_result(
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
      success = described_class.from_result(
        task_id: "id", run_result: mock_result, duration: 1.0, trace_id: "t"
      )

      expect(success).to be_success
      expect(success).not_to be_failure
    end

    it "supports pattern matching" do
      success = described_class.from_result(
        task_id: "id", run_result: mock_result, duration: 1.0, trace_id: "t"
      )

      matched = case success
                in Smolagents::RactorSuccess[output:, success: true] # rubocop:disable RSpec/DescribedClass -- pattern matching requires constants
                  output
                else
                  nil
                end

      expect(matched).to eq("Result output")
    end
  end

  describe Smolagents::RactorFailure do
    let(:instance) { described_class.from_exception(task_id: "id", error: StandardError.new("err"), trace_id: "t") }

    it_behaves_like "a frozen type"
    it_behaves_like "a pattern matchable type"

    describe ".from_exception" do
      it "creates failure from exception" do
        error = RuntimeError.new("Something went wrong")

        failure = described_class.from_exception(
          task_id: "task-123",
          error:,
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
      failure = described_class.from_exception(
        task_id: "id", error: StandardError.new("err"), trace_id: "t"
      )

      expect(failure).to be_failure
      expect(failure).not_to be_success
    end

    it "supports pattern matching" do
      failure = described_class.from_exception(
        task_id: "id", error: ArgumentError.new("bad arg"), trace_id: "t"
      )

      matched = case failure
                in Smolagents::RactorFailure[error_class: "ArgumentError", error_message:] # rubocop:disable RSpec/DescribedClass -- pattern matching requires constants
                  error_message
                else
                  nil
                end

      expect(matched).to eq("bad arg")
    end
  end

  describe Smolagents::RactorMessage do
    let(:task) { Smolagents::RactorTask.create(agent_name: "a", prompt: "p") }
    let(:instance) { described_class.task(task) }

    it_behaves_like "a frozen type"
    it_behaves_like "a pattern matchable type"

    describe ".task" do
      it "wraps a task" do
        message = described_class.task(task)

        expect(message).to be_task
        expect(message).not_to be_result
        expect(message.payload).to eq(task)
      end
    end

    describe ".result" do
      it "wraps a result" do
        mock_result = double("RunResult", output: "out", steps: [], token_usage: nil) # rubocop:disable RSpec/VerifiedDoubles -- duck-typed RunResult interface
        success = Smolagents::RactorSuccess.from_result(
          task_id: "id", run_result: mock_result, duration: 1.0, trace_id: "t"
        )
        message = described_class.result(success)

        expect(message).to be_result
        expect(message).not_to be_task
        expect(message.payload).to eq(success)
      end
    end

    it "supports pattern matching" do
      task = Smolagents::RactorTask.create(agent_name: "test", prompt: "hello")
      message = described_class.task(task)

      matched = case message
                in Smolagents::RactorMessage[type: :task, payload:] # rubocop:disable RSpec/DescribedClass -- pattern matching requires constants
                  payload.agent_name
                else
                  nil
                end

      expect(matched).to eq("test")
    end
  end

  describe Smolagents::OrchestratorResult do
    # rubocop:disable RSpec/VerifiedDoubles -- duck-typed RunResult interface
    let(:mock_result) do
      double("RunResult", output: "out", steps: [1],
                          token_usage: Smolagents::TokenUsage.new(input_tokens: 50, output_tokens: 25))
    end
    let(:first_success) { Smolagents::RactorSuccess.from_result(task_id: "1", run_result: mock_result, duration: 1.0, trace_id: "t1") }
    let(:second_success) { Smolagents::RactorSuccess.from_result(task_id: "2", run_result: mock_result, duration: 1.5, trace_id: "t2") }
    let(:first_failure) { Smolagents::RactorFailure.from_exception(task_id: "3", error: RuntimeError.new("fail"), trace_id: "t3") }
    let(:instance) { described_class.create(succeeded: [first_success], failed: [], duration: 1.0) }

    it_behaves_like "a frozen type"
    it_behaves_like "a pattern matchable type"

    describe ".create" do
      it "creates result with frozen arrays" do
        result = described_class.create(
          succeeded: [first_success, second_success],
          failed: [first_failure],
          duration: 2.5
        )

        expect(result.succeeded).to be_frozen
        expect(result.failed).to be_frozen
        expect(result.duration).to eq(2.5)
      end
    end

    describe "aggregate methods" do
      it "reports success/failure counts" do
        result = described_class.create(
          succeeded: [first_success, second_success],
          failed: [first_failure],
          duration: 2.0
        )

        expect(result.success_count).to eq(2)
        expect(result.failure_count).to eq(1)
        expect(result.total_count).to eq(3)
        expect(result).not_to be_all_success
        expect(result).to be_any_success
      end

      it "reports all_success when no failures" do
        result = described_class.create(
          succeeded: [first_success],
          failed: [],
          duration: 1.0
        )

        expect(result).to be_all_success
      end

      it "calculates total tokens" do
        result = described_class.create(
          succeeded: [first_success, second_success],
          failed: [],
          duration: 2.0
        )

        expect(result.total_tokens).to eq(150) # (50+25) * 2
      end

      it "calculates total steps" do
        result = described_class.create(
          succeeded: [first_success, second_success],
          failed: [],
          duration: 2.0
        )

        expect(result.total_steps).to eq(2) # 1 + 1
      end

      it "extracts outputs and errors" do
        result = described_class.create(
          succeeded: [first_success],
          failed: [first_failure],
          duration: 2.0
        )

        expect(result.outputs).to eq(["out"])
        expect(result.errors).to eq(["fail"])
      end
    end

    it "supports pattern matching" do
      result = described_class.create(
        succeeded: [first_success, second_success],
        failed: [],
        duration: 2.0
      )

      matched = case result
                in Smolagents::OrchestratorResult[all_success: true, success_count:] # rubocop:disable RSpec/DescribedClass -- pattern matching requires constants
                  success_count
                else
                  nil
                end

      expect(matched).to eq(2)
    end
    # rubocop:enable RSpec/VerifiedDoubles
  end
end
