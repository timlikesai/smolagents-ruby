require "spec_helper"

RSpec.describe Smolagents::Testing::Capabilities do
  describe "DIMENSIONS" do
    it "defines orthogonal capability dimensions" do
      expect(described_class::DIMENSIONS).to be_a(Hash)
      expect(described_class::DIMENSIONS).to be_frozen
    end

    it "includes required text dimension" do
      text = described_class::DIMENSIONS[:text]
      expect(text[:required]).to be true
      expect(text[:tests]).to eq([:basic_response])
    end

    it "includes optional capability dimensions" do
      %i[code tool_use reasoning vision].each do |cap|
        dim = described_class::DIMENSIONS[cap]
        expect(dim[:required]).to be false
        expect(dim[:tests]).to be_an(Array)
      end
    end
  end

  describe "REGISTRY" do
    it "contains all test cases referenced in DIMENSIONS" do
      all_tests = described_class::DIMENSIONS.values.flat_map { |d| d[:tests] }
      all_tests.each do |test_name|
        expect(described_class::REGISTRY).to have_key(test_name)
      end
    end

    it "is frozen" do
      expect(described_class::REGISTRY).to be_frozen
    end

    it "contains TestCase instances" do
      described_class::REGISTRY.each_value do |tc|
        expect(tc).to be_a(Smolagents::Testing::TestCase)
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

  describe ".all" do
    it "returns all test cases" do
      all = described_class.all
      expect(all).to be_an(Array)
      expect(all.size).to eq(described_class::REGISTRY.size)
      expect(all).to all(be_a(Smolagents::Testing::TestCase))
    end
  end

  describe ".for_capability" do
    it "returns test cases for a specific capability" do
      tool_tests = described_class.for_capability(:tool_use)
      expect(tool_tests.map(&:name)).to contain_exactly("single_tool", "multi_tool")
    end

    it "returns empty array for capability with no tests" do
      tests = described_class.for_capability(:unknown)
      expect(tests).to eq([])
    end

    it "returns tests matching dimension metadata" do
      described_class::DIMENSIONS.each do |cap, dim|
        tests = described_class.for_capability(cap)
        expect(tests.map { |t| t.name.to_sym }).to match_array(dim[:tests])
      end
    end
  end

  describe ".capabilities" do
    it "returns all capability dimension names" do
      caps = described_class.capabilities
      expect(caps).to contain_exactly(:text, :code, :tool_use, :reasoning, :vision)
    end
  end

  describe ".dimension" do
    it "retrieves dimension metadata" do
      dim = described_class.dimension(:tool_use)
      expect(dim[:tests]).to eq(%i[single_tool multi_tool])
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
end
