require "spec_helper"

RSpec.describe Smolagents::Executors::Executor::ResultBuilder do
  # Create a test class that includes ResultBuilder
  let(:builder_class) do
    Class.new do
      include Smolagents::Executors::Executor::ResultBuilder

      def initialize(max_output_length: 1000)
        @max_output_length = max_output_length
      end
    end
  end

  let(:builder) { builder_class.new }

  describe "#build_result" do
    it "creates ExecutionResult with output and logs" do
      result = builder.build_result(42, "processing...")

      expect(result).to be_a(Smolagents::Executors::ExecutionResult)
      expect(result.output).to eq(42)
      expect(result.logs).to eq("processing...")
      expect(result.error).to be_nil
      expect(result.final_answer).to be false
    end

    it "creates result with error" do
      result = builder.build_result(nil, "", error: "something broke")

      expect(result.error).to eq("something broke")
      expect(result.output).to be_nil
    end

    it "creates result with final_answer flag" do
      result = builder.build_result("answer", "done", is_final: true)

      expect(result.final_answer).to be true
      expect(result.output).to eq("answer")
    end

    it "handles nil logs" do
      result = builder.build_result(100, nil)

      expect(result.logs).to eq("")
    end

    it "handles empty string logs" do
      result = builder.build_result("data", "")

      expect(result.logs).to eq("")
    end
  end

  describe "log truncation" do
    it "truncates logs exceeding max_output_length" do
      builder = builder_class.new(max_output_length: 10)
      long_logs = "a" * 100

      result = builder.build_result(nil, long_logs)

      expect(result.logs.length).to eq(10)
      expect(result.logs).to eq("a" * 10)
    end

    it "preserves logs shorter than max_output_length" do
      builder = builder_class.new(max_output_length: 100)
      short_logs = "hello"

      result = builder.build_result(nil, short_logs)

      expect(result.logs).to eq("hello")
    end

    it "handles logs exactly at max_output_length" do
      builder = builder_class.new(max_output_length: 5)
      exact_logs = "exact"

      result = builder.build_result(nil, exact_logs)

      expect(result.logs).to eq("exact")
    end

    it "handles multi-byte characters correctly" do
      builder = builder_class.new(max_output_length: 10)
      # Multi-byte characters (emoji is 4 bytes in UTF-8)
      logs_with_emoji = "ab\u{1F600}cd"

      result = builder.build_result(nil, logs_with_emoji)

      # byteslice may cut in the middle of a multi-byte char
      expect(result.logs.bytesize).to be <= 10
    end
  end

  describe "#max_output_length accessor" do
    it "exposes max_output_length via attr_reader" do
      builder = builder_class.new(max_output_length: 500)

      expect(builder.max_output_length).to eq(500)
    end
  end
end
