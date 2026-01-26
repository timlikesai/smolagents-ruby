require "smolagents/concerns/agents/react_loop/error_handling"

RSpec.describe Smolagents::Concerns::ReActLoop::ErrorHandling do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::ErrorHandling

      attr_accessor :logger, :max_steps, :model

      def cleanup_resources
        @model.close_connections if @model.respond_to?(:close_connections)
      end

      def build_result(state, output, ctx, memory:)
        Smolagents::Types::RunResult.success(output: output || "error", steps: memory.steps)
      end
    end
  end

  let(:instance) do
    obj = test_class.new
    obj.logger = double("logger", error: nil, warn: nil)
    obj.max_steps = 10
    obj
  end

  describe "#finalize_error" do
    let(:error) do
      err = StandardError.new("Test error")
      err.set_backtrace(%w[line1 line2 line3 line4])
      err
    end
    let(:ctx) { double("context", finish: double("finished_ctx")) }
    let(:memory) { double("memory", steps: []) }

    it "logs the error with backtrace" do
      allow(instance.logger).to receive(:error)
      instance.send(:finalize_error, error, ctx, memory:)
      expect(instance.logger).to have_received(:error).with(
        "Agent error",
        hash_including(error: "Test error")
      )
    end

    it "cleans up resources" do
      instance.model = double("model", close_connections: nil)
      allow(instance.model).to receive(:close_connections)
      instance.send(:finalize_error, error, ctx, memory:)
      expect(instance.model).to have_received(:close_connections)
    end

    it "returns a RunResult" do
      result = instance.send(:finalize_error, error, ctx, memory:)

      expect(result).to be_a(Smolagents::Types::RunResult)
    end
  end

  describe "error handling behavior" do
    it "handles errors without raising" do
      error = RuntimeError.new("Something went wrong")
      error.set_backtrace(%w[line1 line2])
      ctx = double("context", finish: double("finished"))
      memory = double("memory", steps: [])

      result = instance.send(:finalize_error, error, ctx, memory:)

      expect(result).to be_a(Smolagents::Types::RunResult)
    end
  end
end
