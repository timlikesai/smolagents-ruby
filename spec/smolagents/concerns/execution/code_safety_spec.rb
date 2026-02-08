require "smolagents"

RSpec.describe Smolagents::Concerns::CodeSafety do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::CodeSafety

      public :validate_code_safety
    end
  end

  let(:checker) { test_class.new }

  describe "#validate_code_safety" do
    context "with safe code" do
      it "allows simple output" do
        result = checker.validate_code_safety('puts "hello"')
        expect(result).to be_safe
        expect(result.reason).to be_nil
      end

      it "allows small array allocations" do
        result = checker.validate_code_safety("Array.new(100)")
        expect(result).to be_safe
      end

      it "allows small string multiplication" do
        result = checker.validate_code_safety('"x" * 100')
        expect(result).to be_safe
      end
    end

    context "with massive array allocations" do
      it "rejects Array.new(10**9)" do
        result = checker.validate_code_safety("Array.new(10**9)")
        expect(result).to be_rejected
        expect(result.reason).to include("Massive allocation")
      end

      it "rejects Array.new(10**7)" do
        result = checker.validate_code_safety("Array.new(10**7)")
        expect(result).to be_rejected
        expect(result.reason).to include("Massive allocation")
      end

      it "rejects Array.new with literal size >= 10^8" do
        result = checker.validate_code_safety("Array.new(100000000)")
        expect(result).to be_rejected
        expect(result.reason).to include("Massive allocation")
        expect(result.reason).to include("literal size")
      end
    end

    context "with massive string multiplication" do
      it "rejects string * 10**8" do
        result = checker.validate_code_safety('"x" * 10**8')
        expect(result).to be_rejected
        expect(result.reason).to include("string multiplication")
      end

      it "rejects string * literal >= 10^8" do
        result = checker.validate_code_safety('"x" * 100000000')
        expect(result).to be_rejected
        expect(result.reason).to include("string multiplication")
      end
    end

    context "with unbounded loops" do
      it "rejects while true without break" do
        result = checker.validate_code_safety("while true\nend")
        expect(result).to be_rejected
        expect(result.reason).to include("Unbounded loop")
        expect(result.reason).to include("while true")
      end

      it "rejects loop do without break" do
        result = checker.validate_code_safety("loop do\nend")
        expect(result).to be_rejected
        expect(result.reason).to include("Unbounded loop")
        expect(result.reason).to include("loop")
      end
    end

    context "with bounded loops" do
      it "allows while true with break" do
        result = checker.validate_code_safety("while true\nbreak if done\nend")
        expect(result).to be_safe
      end

      it "allows loop do with break" do
        result = checker.validate_code_safety("loop do\nbreak\nend")
        expect(result).to be_safe
      end
    end

    context "with Float::INFINITY allocation" do
      it "rejects .new(Float::INFINITY)" do
        result = checker.validate_code_safety("SomeClass.new(Float::INFINITY)")
        expect(result).to be_rejected
        expect(result.reason).to include("infinite size")
      end
    end

    context "return type" do
      it "returns a CodeSafetyResult for safe code" do
        result = checker.validate_code_safety("1 + 1")
        expect(result).to be_a(Smolagents::Types::CodeSafetyResult)
        expect(result.outcome).to eq(:safe)
      end

      it "returns a CodeSafetyResult for rejected code" do
        result = checker.validate_code_safety("Array.new(10**9)")
        expect(result).to be_a(Smolagents::Types::CodeSafetyResult)
        expect(result.outcome).to eq(:rejected)
      end
    end
  end
end
