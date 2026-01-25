RSpec.describe "Model Test Shared Examples" do
  # Create a mock model class for testing the shared examples
  let(:mock_model_class) do
    Class.new do
      attr_reader :model_id

      def initialize(model_id: "test-model", **)
        @model_id = model_id
        @mock = Smolagents::Testing::MockModel.new
      end

      def generate(messages)
        @mock.generate(messages)
      end

      def call(messages)
        generate(messages)
      end

      # Delegate MockModel methods for setup
      def queue_final_answer(answer)
        @mock.queue_final_answer(answer)
        self
      end

      def queue_code_action(code)
        @mock.queue_code_action(code)
        self
      end

      def queue_evaluation_continue
        @mock.queue_evaluation_continue
        self
      end
    end
  end

  describe "a model that passes basic tests" do
    describe "with valid configuration" do
      # Stub the model to return expected responses
      let(:model_config) { { model_id: "mock-model" } }

      before do
        # Stub agent creation to use our mock
        allow(Smolagents::Agents::Agent).to receive(:new).and_wrap_original do |_method, **_args|
          mock = Smolagents::Testing::MockModel.new
          mock.queue_final_answer("4")

          # Return a stub agent that returns what we expect
          instance_double(
            Smolagents::Agents::Agent,
            run: Smolagents::RunResult.new(
              output: "4",
              steps: [double(tokens: 10)],
              state: :success,
              token_usage: Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
            )
          )
        end
      end

      it "creates test using Smolagents.test(:model)" do
        builder = Smolagents.test(:model)
                            .task("What is 2+2?")
                            .expects { |out| out.to_s.include?("4") }

        expect(builder).to be_a(Smolagents::Builders::TestBuilder)
        expect(builder.config[:task]).to eq("What is 2+2?")
      end
    end
  end

  describe "a model that handles tool calling" do
    it "accepts tool_name parameter" do
      # Verify the shared example can be instantiated with a tool name
      expect do
        RSpec.describe "Tool Test" do
          let(:model_config) { { model_id: "test" } }

          it_behaves_like "a model that handles tool calling", :calculator
        end
      end.not_to raise_error
    end
  end

  describe "a reliable model" do
    it "accepts pass_threshold and runs parameters" do
      # Verify the shared example can be instantiated with custom parameters
      expect do
        RSpec.describe "Reliability Test" do
          let(:model_config) { { model_id: "test" } }

          it_behaves_like "a reliable model", pass_threshold: 0.8, runs: 3
        end
      end.not_to raise_error
    end

    it "uses default parameters when not specified" do
      # The shared example should work with defaults
      expect do
        RSpec.describe "Reliability Default Test" do
          let(:model_config) { { model_id: "test" } }

          it_behaves_like "a reliable model"
        end
      end.not_to raise_error
    end
  end

  describe "a model meeting capability requirements" do
    it "accepts array of capabilities" do
      expect do
        RSpec.describe "Capability Test" do
          let(:model_config) { { model_id: "test" } }

          it_behaves_like "a model meeting capability requirements", %i[text tool_use]
        end
      end.not_to raise_error
    end
  end

  describe "TestBuilder integration" do
    it "supports the fluent interface used by shared examples" do
      builder = Smolagents.test(:model)
                          .task("Test task")
                          .expects { |out| out.include?("expected") }
                          .max_steps(3)

      expect(builder.config[:task]).to eq("Test task")
      expect(builder.config[:max_steps]).to eq(3)
      expect(builder.config[:validator]).to be_a(Proc)
    end

    it "supports run_n_times and pass_threshold for reliability testing" do
      builder = Smolagents.test(:model)
                          .task("Reliability task")
                          .run_n_times(5)
                          .pass_threshold(0.9)

      expect(builder.config[:run_count]).to eq(5)
      expect(builder.config[:pass_threshold]).to eq(0.9)
    end

    it "supports from method for loading test cases" do
      test_case = Smolagents::Testing::TestCase.new(
        name: "source_test",
        capability: :text,
        task: "Source task",
        tools: [:search],
        validator: nil,
        max_steps: 8,
        timeout: 90
      )

      builder = Smolagents.test(:model).from(test_case)

      expect(builder.config[:name]).to eq("source_test")
      expect(builder.config[:task]).to eq("Source task")
      expect(builder.config[:tools]).to eq([:search])
      expect(builder.config[:max_steps]).to eq(8)
    end
  end

  describe "Matchers used by shared examples" do
    describe "be_passed" do
      it "matches passed TestRun" do
        run = Smolagents::Testing::TestRun.new(
          test_case: double(name: "test"),
          results: [double(passed: true)],
          threshold: 1.0
        )
        expect(run).to be_passed
      end

      it "does not match failed TestRun" do
        run = Smolagents::Testing::TestRun.new(
          test_case: double(name: "test"),
          results: [double(passed: false)],
          threshold: 1.0
        )
        expect(run).not_to be_passed
      end
    end

    describe "have_completed_in" do
      it "matches exact step count" do
        result = double(steps: 3)
        expect(result).to have_completed_in(steps: 3)
      end

      it "matches step range" do
        result = double(steps: 2)
        expect(result).to have_completed_in(steps: 1..3)
      end

      it "does not match out of range" do
        result = double(steps: 5)
        expect(result).not_to have_completed_in(steps: 1..3)
      end
    end

    describe "have_pass_rate" do
      it "matches with at_least" do
        run = double(pass_rate: 0.95)
        expect(run).to have_pass_rate(at_least: 0.9)
      end

      it "does not match below threshold" do
        run = double(pass_rate: 0.8)
        expect(run).not_to have_pass_rate(at_least: 0.9)
      end
    end
  end

  describe "RequirementBuilder integration" do
    it "supports requires method for capabilities" do
      builder = Smolagents.test_suite(:test_suite)
                          .requires(:text)

      expect(builder.all_test_cases).not_to be_empty
    end

    it "returns test cases for iteration" do
      builder = Smolagents.test_suite(:test_suite)
                          .requires(:text)

      test_cases = builder.all_test_cases
      expect(test_cases).to all(be_a(Smolagents::Testing::TestCase))
    end
  end
end
