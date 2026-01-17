RSpec.describe Smolagents::Testing::TestCase do
  describe "initialization" do
    it "creates with required parameters" do
      test_case = described_class.new(
        name: "basic_test",
        capability: :reasoning,
        task: "What is 2 + 2?"
      )

      expect(test_case.name).to eq("basic_test")
      expect(test_case.capability).to eq(:reasoning)
      expect(test_case.task).to eq("What is 2 + 2?")
    end

    it "applies default values" do
      test_case = described_class.new(
        name: "test",
        capability: :basic,
        task: "Do something"
      )

      expect(test_case.tools).to eq([])
      expect(test_case.validator).to be_nil
      expect(test_case.max_steps).to eq(5)
      expect(test_case.timeout).to eq(60)
    end

    it "allows overriding defaults" do
      validator = ->(r) { r == "success" }
      test_case = described_class.new(
        name: "custom",
        capability: :tool_use,
        task: "Search for something",
        tools: %i[search web],
        validator:,
        max_steps: 10,
        timeout: 120
      )

      expect(test_case.tools).to eq(%i[search web])
      expect(test_case.validator).to eq(validator)
      expect(test_case.max_steps).to eq(10)
      expect(test_case.timeout).to eq(120)
    end
  end

  describe "#with_validator" do
    it "returns a new instance with the validator" do
      original = described_class.new(name: "test", capability: :basic, task: "task")
      validator = lambda(&:success?)

      updated = original.with_validator(validator)

      expect(updated).not_to equal(original)
      expect(updated.validator).to eq(validator)
      expect(original.validator).to be_nil
    end

    it "preserves other attributes" do
      original = described_class.new(
        name: "test",
        capability: :reasoning,
        task: "task",
        tools: [:search],
        max_steps: 8,
        timeout: 90
      )

      updated = original.with_validator(->(_) { true })

      expect(updated.name).to eq("test")
      expect(updated.capability).to eq(:reasoning)
      expect(updated.task).to eq("task")
      expect(updated.tools).to eq([:search])
      expect(updated.max_steps).to eq(8)
      expect(updated.timeout).to eq(90)
    end
  end

  describe "#with_timeout" do
    it "returns a new instance with the timeout" do
      original = described_class.new(name: "test", capability: :basic, task: "task")

      updated = original.with_timeout(180)

      expect(updated).not_to equal(original)
      expect(updated.timeout).to eq(180)
      expect(original.timeout).to eq(60)
    end
  end

  describe "#with_tools" do
    it "returns a new instance with the tools" do
      original = described_class.new(name: "test", capability: :basic, task: "task")

      updated = original.with_tools(:search, :web)

      expect(updated).not_to equal(original)
      expect(updated.tools).to eq(%i[search web])
      expect(original.tools).to eq([])
    end

    it "flattens nested arrays" do
      original = described_class.new(name: "test", capability: :basic, task: "task")

      updated = original.with_tools(%i[search web], :browser)

      expect(updated.tools).to eq(%i[search web browser])
    end
  end

  describe "#with_max_steps" do
    it "returns a new instance with max_steps" do
      original = described_class.new(name: "test", capability: :basic, task: "task")

      updated = original.with_max_steps(15)

      expect(updated).not_to equal(original)
      expect(updated.max_steps).to eq(15)
      expect(original.max_steps).to eq(5)
    end
  end

  describe "#to_h" do
    it "returns a hash representation without validator" do
      test_case = described_class.new(
        name: "test",
        capability: :reasoning,
        task: "What is 2 + 2?",
        tools: [:calculator],
        validator: ->(r) { r == "4" },
        max_steps: 3,
        timeout: 30
      )

      result = test_case.to_h

      expect(result).to eq({
                             name: "test",
                             capability: :reasoning,
                             task: "What is 2 + 2?",
                             tools: [:calculator],
                             max_steps: 3,
                             timeout: 30
                           })
      expect(result).not_to have_key(:validator)
    end
  end

  describe "#deconstruct_keys" do
    it "enables pattern matching" do
      test_case = described_class.new(
        name: "pattern_test",
        capability: :tool_use,
        task: "Search task",
        tools: [:search]
      )

      case test_case
      in { name: n, capability: :tool_use, tools: t }
        expect(n).to eq("pattern_test")
        expect(t).to eq([:search])
      else
        raise "Pattern should have matched"
      end
    end

    it "returns same keys as to_h" do
      test_case = described_class.new(
        name: "test",
        capability: :basic,
        task: "task"
      )

      expect(test_case.deconstruct_keys(nil)).to eq(test_case.to_h)
    end
  end

  describe "immutability" do
    it "is immutable" do
      test_case = described_class.new(name: "test", capability: :basic, task: "task")

      expect { test_case.instance_variable_set(:@name, "changed") }
        .to raise_error(FrozenError)
    end
  end

  describe "fluent chaining" do
    it "supports chained modifications" do
      original = described_class.new(name: "base", capability: :reasoning, task: "Base task")

      result = original
               .with_tools(:search, :web)
               .with_timeout(120)
               .with_max_steps(10)
               .with_validator(lambda(&:success?))

      expect(result.tools).to eq(%i[search web])
      expect(result.timeout).to eq(120)
      expect(result.max_steps).to eq(10)
      expect(result.validator).not_to be_nil

      # Original unchanged
      expect(original.tools).to eq([])
      expect(original.timeout).to eq(60)
      expect(original.max_steps).to eq(5)
      expect(original.validator).to be_nil
    end
  end
end
