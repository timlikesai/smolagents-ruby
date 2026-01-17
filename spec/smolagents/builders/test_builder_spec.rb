require "smolagents/testing"

RSpec.describe Smolagents::Builders::TestBuilder do
  describe "#initialize" do
    it "creates builder with default configuration" do
      builder = described_class.new

      expect(builder.config[:task]).to be_nil
      expect(builder.config[:validator]).to be_nil
      expect(builder.config[:tools]).to eq([])
      expect(builder.config[:max_steps]).to eq(5)
      expect(builder.config[:timeout]).to eq(60)
      expect(builder.config[:run_count]).to eq(1)
      expect(builder.config[:pass_threshold]).to eq(1.0)
      expect(builder.config[:metrics]).to eq([])
      expect(builder.config[:name]).to be_nil
      expect(builder.config[:capability]).to eq(:text)
    end
  end

  describe "#task" do
    it "sets the task prompt" do
      builder = described_class.new.task("What is 2 + 2?")

      expect(builder.config[:task]).to eq("What is 2 + 2?")
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.task("test")

      expect(result).to be(builder)
    end
  end

  describe "#expects" do
    it "sets a validation block" do
      validator = proc { |r| r.include?("4") }
      builder = described_class.new.expects(&validator)

      expect(builder.config[:validator]).to eq(validator)
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.expects { |r| r == "4" }

      expect(result).to be(builder)
    end
  end

  describe "#expects_validator" do
    it "sets a validator object" do
      validator = ->(r) { r == "4" }
      builder = described_class.new.expects_validator(validator)

      expect(builder.config[:validator]).to eq(validator)
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.expects_validator(->(r) { r })

      expect(result).to be(builder)
    end
  end

  describe "#tools" do
    it "sets the tools list" do
      builder = described_class.new.tools(:search, :web)

      expect(builder.config[:tools]).to eq(%i[search web])
    end

    it "flattens nested arrays" do
      builder = described_class.new.tools(%i[search web])

      expect(builder.config[:tools]).to eq(%i[search web])
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.tools(:search)

      expect(result).to be(builder)
    end
  end

  describe "#max_steps" do
    it "sets maximum steps" do
      builder = described_class.new.max_steps(10)

      expect(builder.config[:max_steps]).to eq(10)
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.max_steps(8)

      expect(result).to be(builder)
    end
  end

  describe "#timeout" do
    it "sets timeout in seconds" do
      builder = described_class.new.timeout(120)

      expect(builder.config[:timeout]).to eq(120)
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.timeout(30)

      expect(result).to be(builder)
    end
  end

  describe "#run_n_times" do
    it "sets the run count for reliability testing" do
      builder = described_class.new.run_n_times(5)

      expect(builder.config[:run_count]).to eq(5)
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.run_n_times(3)

      expect(result).to be(builder)
    end
  end

  describe "#pass_threshold" do
    it "sets the pass threshold" do
      builder = described_class.new.pass_threshold(0.8)

      expect(builder.config[:pass_threshold]).to eq(0.8)
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.pass_threshold(0.5)

      expect(result).to be(builder)
    end
  end

  describe "#metrics" do
    it "sets metrics to collect" do
      builder = described_class.new.metrics(:latency, :tokens)

      expect(builder.config[:metrics]).to eq(%i[latency tokens])
    end

    it "flattens nested arrays" do
      builder = described_class.new.metrics(%i[latency tokens])

      expect(builder.config[:metrics]).to eq(%i[latency tokens])
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.metrics(:latency)

      expect(result).to be(builder)
    end
  end

  describe "#name" do
    it "sets the test name" do
      builder = described_class.new.name("arithmetic_test")

      expect(builder.config[:name]).to eq("arithmetic_test")
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.name("test")

      expect(result).to be(builder)
    end
  end

  describe "#capability" do
    it "sets the capability being tested" do
      builder = described_class.new.capability(:tool_use)

      expect(builder.config[:capability]).to eq(:tool_use)
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.capability(:reasoning)

      expect(result).to be(builder)
    end
  end

  describe "#build_test_case" do
    it "creates a TestCase from configuration" do
      builder = described_class.new
                               .name("my_test")
                               .capability(:tool_use)
                               .task("Find Ruby version")
                               .tools(:search)
                               .max_steps(8)
                               .timeout(120)

      test_case = builder.build_test_case

      expect(test_case).to be_a(Smolagents::Testing::TestCase)
      expect(test_case.name).to eq("my_test")
      expect(test_case.capability).to eq(:tool_use)
      expect(test_case.task).to eq("Find Ruby version")
      expect(test_case.tools).to eq([:search])
      expect(test_case.max_steps).to eq(8)
      expect(test_case.timeout).to eq(120)
    end

    it "generates a random name if not provided" do
      builder = described_class.new.task("test task")

      test_case = builder.build_test_case

      expect(test_case.name).to match(/^test_[a-f0-9]{8}$/)
    end

    it "includes the validator" do
      validator = proc { |r| r == "4" }
      builder = described_class.new
                               .task("What is 2 + 2?")
                               .expects(&validator)

      test_case = builder.build_test_case

      expect(test_case.validator).to eq(validator)
    end
  end

  describe "#from" do
    let(:existing_test_case) do
      Smolagents::Testing::TestCase.new(
        name: "existing_test",
        capability: :reasoning,
        task: "Solve a problem",
        tools: %i[search web],
        validator: ->(r) { r.include?("answer") },
        max_steps: 10,
        timeout: 90
      )
    end

    it "populates builder from existing test case" do
      builder = described_class.new.from(existing_test_case)

      expect(builder.config[:name]).to eq("existing_test")
      expect(builder.config[:capability]).to eq(:reasoning)
      expect(builder.config[:task]).to eq("Solve a problem")
      expect(builder.config[:tools]).to eq(%i[search web])
      expect(builder.config[:max_steps]).to eq(10)
      expect(builder.config[:timeout]).to eq(90)
    end

    it "returns self for chaining" do
      builder = described_class.new
      result = builder.from(existing_test_case)

      expect(result).to be(builder)
    end

    it "allows further modifications" do
      builder = described_class.new
                               .from(existing_test_case)
                               .max_steps(15)

      expect(builder.config[:max_steps]).to eq(15)
      expect(builder.config[:name]).to eq("existing_test")
    end
  end

  describe "#config" do
    it "returns a frozen copy of configuration" do
      builder = described_class.new.task("test")
      config = builder.config

      expect(config).to be_frozen
    end

    it "returns a duplicate - modifications do not affect builder" do
      builder = described_class.new.task("original")
      config = builder.config

      # We can't modify the frozen hash, but verify it's independent
      expect(config[:task]).to eq("original")
      builder.task("modified")
      expect(builder.config[:task]).to eq("modified")
    end
  end

  describe "chaining" do
    it "supports full configuration chain" do
      builder = described_class.new
                               .name("full_test")
                               .task("What is 2 + 2?")
                               .tools(:calculator)
                               .max_steps(5)
                               .timeout(30)
                               .run_n_times(3)
                               .pass_threshold(0.8)
                               .metrics(:latency, :tokens)
                               .capability(:reasoning)
                               .expects { |r| r.include?("4") }

      config = builder.config

      expect(config[:name]).to eq("full_test")
      expect(config[:task]).to eq("What is 2 + 2?")
      expect(config[:tools]).to eq([:calculator])
      expect(config[:max_steps]).to eq(5)
      expect(config[:timeout]).to eq(30)
      expect(config[:run_count]).to eq(3)
      expect(config[:pass_threshold]).to eq(0.8)
      expect(config[:metrics]).to eq(%i[latency tokens])
      expect(config[:capability]).to eq(:reasoning)
      expect(config[:validator]).to be_a(Proc)
    end
  end
end
