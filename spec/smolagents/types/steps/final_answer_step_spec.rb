require "spec_helper"

RSpec.describe Smolagents::Types::FinalAnswerStep do
  let(:step) { described_class.new(output: "The answer is 42") }

  it_behaves_like "a step type", message_count: 0 do
    let(:step) { described_class.new(output: "result") }
  end

  describe ".new" do
    it "creates a final answer step with output" do
      result = described_class.new(output: "Hello world")
      expect(result.output).to eq("Hello world")
    end

    it "accepts any output type" do
      result = described_class.new(output: { key: "value" })
      expect(result.output).to eq({ key: "value" })
    end

    it "accepts nil output" do
      result = described_class.new(output: nil)
      expect(result.output).to be_nil
    end
  end

  describe "#to_h" do
    it "returns hash with output key" do
      expect(step.to_h).to eq({ output: "The answer is 42" })
    end

    it "preserves complex output types" do
      complex = described_class.new(output: [1, 2, 3])
      expect(complex.to_h).to eq({ output: [1, 2, 3] })
    end
  end

  describe "#to_messages" do
    it "returns empty array" do
      expect(step.to_messages).to eq([])
    end

    it "ignores any options passed" do
      expect(step.to_messages(summary_mode: true)).to eq([])
      expect(step.to_messages(foo: "bar")).to eq([])
    end
  end

  describe "#deconstruct_keys" do
    it "returns hash for pattern matching" do
      expect(step.deconstruct_keys(nil)).to eq({ output: "The answer is 42" })
    end

    it "ignores keys argument" do
      expect(step.deconstruct_keys([:output])).to eq({ output: "The answer is 42" })
      expect(step.deconstruct_keys([:nonexistent])).to eq({ output: "The answer is 42" })
    end
  end

  describe "pattern matching" do
    it "matches on output" do
      result = case step
               in { output: o }
                 o
               end

      expect(result).to eq("The answer is 42")
    end

    it "allows conditional matching" do
      result = case step
               in { output: String => s } then "string: #{s}"
               in { output: Hash } then "hash"
               else "other"
               end

      expect(result).to eq("string: The answer is 42")
    end
  end
end
