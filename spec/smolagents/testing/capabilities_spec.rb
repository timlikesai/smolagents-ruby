require "spec_helper"

RSpec.describe Smolagents::Testing::Capabilities do
  describe ".register" do
    before { described_class.reset! }

    it "registers a new test case" do
      tc = described_class.register(:custom,
                                    name: "my_test",
                                    task: "Do something",
                                    validator: ->(r) { r.include?("done") })

      expect(tc).to be_a(Smolagents::Testing::TestCase)
      expect(tc.name).to eq("my_test")
      expect(tc.capability).to eq(:custom)
    end

    it "adds the capability to dimensions" do
      described_class.register(:new_cap, name: "test1", task: "Task")
      expect(described_class.capabilities).to include(:new_cap)
    end

    it "accumulates tests under the same capability" do
      described_class.register(:multi, name: "test1", task: "Task 1")
      described_class.register(:multi, name: "test2", task: "Task 2")

      tests = described_class.for_capability(:multi)
      expect(tests.map(&:name)).to contain_exactly("test1", "test2")
    end
  end

  describe "core capabilities" do
    it "includes required text dimension" do
      dim = described_class.dimension(:text)
      expect(dim[:required]).to be true
      expect(dim[:tests]).to include(:basic_response)
    end

    it "includes optional capability dimensions" do
      %i[code tool_use reasoning vision].each do |cap|
        dim = described_class.dimension(cap)
        expect(dim[:required]).to be false
        expect(dim[:tests]).to be_an(Array)
      end
    end
  end

  describe ".get" do
    it "retrieves a test case by key" do
      tc = described_class.get(:basic_response)
      expect(tc.name).to eq("basic_response")
      expect(tc.capability).to eq(:text)
    end

    it "raises KeyError for unknown key" do
      expect { described_class.get(:nonexistent) }.to raise_error(KeyError)
    end
  end

  describe ".test?" do
    it "returns true for existing tests" do
      expect(described_class.test?(:basic_response)).to be true
    end

    it "returns false for unknown tests" do
      expect(described_class.test?(:nonexistent)).to be false
    end
  end

  describe ".all" do
    it "returns all test cases" do
      all = described_class.all
      expect(all).to be_an(Array)
      expect(all).to all(be_a(Smolagents::Testing::TestCase))
    end

    it "includes core test cases" do
      names = described_class.all.map(&:name)
      expect(names).to include("basic_response", "code_format", "single_tool")
    end
  end

  describe ".for_capability" do
    it "returns test cases for a specific capability" do
      tool_tests = described_class.for_capability(:tool_use)
      expect(tool_tests.map(&:name)).to include("single_tool", "multi_tool")
    end

    it "returns empty array for capability with no tests" do
      tests = described_class.for_capability(:unknown)
      expect(tests).to eq([])
    end
  end

  describe ".capabilities" do
    it "returns all capability dimension names" do
      caps = described_class.capabilities
      expect(caps).to include(:text, :code, :tool_use, :reasoning, :vision)
    end
  end

  describe ".capability?" do
    it "returns true for existing capabilities" do
      expect(described_class.capability?(:text)).to be true
    end

    it "returns false for unknown capabilities" do
      expect(described_class.capability?(:nonexistent)).to be false
    end
  end

  describe ".dimension" do
    it "retrieves dimension metadata" do
      dim = described_class.dimension(:tool_use)
      expect(dim[:tests]).to include(:single_tool, :multi_tool)
      expect(dim[:required]).to be false
    end

    it "raises KeyError for unknown capability" do
      expect { described_class.dimension(:nonexistent) }.to raise_error(KeyError)
    end
  end

  describe "test case definitions" do
    describe "basic_response" do
      subject(:tc) { described_class.get(:basic_response) }

      it "has correct attributes" do
        expect(tc.capability).to eq(:text)
        expect(tc.tools).to eq([])
        expect(tc.max_steps).to eq(4)
        expect(tc.timeout).to eq(30)
      end

      it "has a validator that checks for '4'" do
        expect(tc.validator.call("The answer is 4")).to be true
        expect(tc.validator.call("The answer is 5")).to be false
      end
    end

    describe "code_format" do
      subject(:tc) { described_class.get(:code_format) }

      it "has correct attributes" do
        expect(tc.capability).to eq(:code)
        expect(tc.tools).to eq([])
      end

      it "validates code block with puts hello world" do
        valid_response = "```ruby\nputs 'Hello, World!'\n```"
        expect(tc.validator.call(valid_response)).to be true

        invalid_response = "puts 'Hello, World!'"
        expect(tc.validator.call(invalid_response)).to be false
      end
    end

    describe "single_tool" do
      subject(:tc) { described_class.get(:single_tool) }

      it "requires calculator tool" do
        expect(tc.tools).to eq([:calculator])
      end

      it "validates for '100'" do
        expect(tc.validator.call("The result is 100")).to be true
      end
    end

    describe "multi_tool" do
      subject(:tc) { described_class.get(:multi_tool) }

      it "has higher limits than single_tool" do
        single = described_class.get(:single_tool)
        expect(tc.max_steps).to be > single.max_steps
        expect(tc.timeout).to be > single.timeout
      end
    end

    describe "reasoning" do
      subject(:tc) { described_class.get(:reasoning) }

      it "tests year calculation" do
        expect(tc.validator.call("2023")).to be true
        expect(tc.validator.call("2020")).to be false
      end
    end

    describe "vision tests" do
      it "vision_basic validates color words" do
        tc = described_class.get(:vision_basic)
        expect(tc.validator.call("The image shows a red apple")).to be true
        expect(tc.validator.call("The image shows an apple")).to be false
      end

      it "vision_ocr validates text extraction" do
        tc = described_class.get(:vision_ocr)
        expect(tc.validator.call("Hello")).to be true
        expect(tc.validator.call("contains text")).to be true
        expect(tc.validator.call("no")).to be false
      end
    end
  end

  describe "tool execution capabilities" do
    it "registers variable persistence tests" do
      expect(described_class.capability?(:variable_persistence)).to be true
      tests = described_class.for_capability(:variable_persistence)
      expect(tests.map(&:name)).to include("store_and_retrieve")
    end

    it "registers sequential tools tests" do
      expect(described_class.capability?(:sequential_tools)).to be true
      tests = described_class.for_capability(:sequential_tools)
      expect(tests.map(&:name)).to include("chain_two_tools")
    end

    it "registers error recovery tests" do
      expect(described_class.capability?(:error_recovery)).to be true
      tests = described_class.for_capability(:error_recovery)
      expect(tests.map(&:name)).to include("handle_tool_error")
    end
  end
end
