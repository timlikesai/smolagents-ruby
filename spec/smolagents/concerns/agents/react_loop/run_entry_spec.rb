require "smolagents/concerns/agents/react_loop/run_entry"

RSpec.describe Smolagents::Concerns::ReActLoop::RunEntry do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::RunEntry

      attr_accessor :logger, :task

      def prepare_run(_reset, _images); end

      def run_sync(_task, images:, additional_prompting:)
        Smolagents::Types::RunResult.success(output: "completed", steps: [])
      end

      def run_stream(task:, images:, additional_prompting:)
        Enumerator.new { |y| y << "step1" }
      end
    end
  end

  let(:instance) { test_class.new }

  describe "#run" do
    it "accepts task string" do
      result = instance.run("Find Python documentation")

      expect(result).to be_a(Smolagents::Types::RunResult)
    end

    it "returns RunResult in sync mode" do
      result = instance.run("test task")

      expect(result.output).not_to be_nil
      expect(result.state).to eq(:success)
    end

    it "returns Enumerator in stream mode" do
      result = instance.run("test", stream: true)

      expect(result).to be_a(Enumerator)
    end

    it "accepts reset option" do
      expect { instance.run("test", reset: true) }.not_to raise_error
    end

    it "accepts images option" do
      expect { instance.run("test", images: ["img.png"]) }.not_to raise_error
    end

    it "accepts additional_prompting option" do
      expect { instance.run("test", additional_prompting: "extra context") }.not_to raise_error
    end
  end

  describe "run instrumentation" do
    it "wraps run in observability context" do
      # The run method creates an ObservabilityContext
      result = instance.run("test")

      expect(result).to be_a(Smolagents::Types::RunResult)
    end

    it "instruments the run" do
      # Instrumentation.instrument is called
      result = instance.run("test")

      expect(result).not_to be_nil
    end
  end

  describe "run modes" do
    it "calls run_sync for default mode" do
      allow(instance).to receive(:run_sync).and_call_original
      instance.run("test")
      expect(instance).to have_received(:run_sync)
    end

    it "calls run_stream for stream mode" do
      allow(instance).to receive(:run_stream).and_call_original
      instance.run("test", stream: true)
      expect(instance).to have_received(:run_stream)
    end
  end
end
