RSpec.describe Smolagents::Executor do
  describe "ExecutionResult" do
    it "creates result with defaults" do
      result = described_class::ExecutionResult.new
      expect(result.output).to be_nil
      expect(result.logs).to eq("")
      expect(result.error).to be_nil
      expect(result.is_final_answer).to be false
    end

    it "creates successful result" do
      result = described_class::ExecutionResult.new(output: 42, logs: "log output")
      expect(result.output).to eq(42)
      expect(result.logs).to eq("log output")
      expect(result.success?).to be true
      expect(result.failure?).to be false
    end

    it "creates failed result" do
      result = described_class::ExecutionResult.new(error: "Something went wrong")
      expect(result.error).to eq("Something went wrong")
      expect(result.success?).to be false
      expect(result.failure?).to be true
    end

    it "marks final answer" do
      result = described_class::ExecutionResult.new(output: "final", is_final_answer: true)
      expect(result.is_final_answer).to be true
    end

    describe ".success" do
      it "creates successful result with factory" do
        result = described_class::ExecutionResult.success(output: "done", logs: "info")
        expect(result.output).to eq("done")
        expect(result.logs).to eq("info")
        expect(result.error).to be_nil
        expect(result.success?).to be true
      end

      it "supports is_final_answer flag" do
        result = described_class::ExecutionResult.success(output: "final", is_final_answer: true)
        expect(result.is_final_answer).to be true
      end
    end

    describe ".failure" do
      it "creates failure result with factory" do
        result = described_class::ExecutionResult.failure(error: "oops", logs: "debug")
        expect(result.error).to eq("oops")
        expect(result.logs).to eq("debug")
        expect(result.output).to be_nil
        expect(result.failure?).to be true
      end
    end
  end

  describe "#execute" do
    it "raises NotImplementedError" do
      executor = described_class.new
      expect do
        executor.execute("code", language: :ruby)
      end.to raise_error(NotImplementedError, /must implement #execute/)
    end
  end

  describe "#supports?" do
    it "raises NotImplementedError" do
      executor = described_class.new
      expect do
        executor.supports?(:ruby)
      end.to raise_error(NotImplementedError, /must implement #supports\?/)
    end
  end

  describe "#send_tools" do
    it "stores tools" do
      executor = described_class.new
      tools = { "test" => instance_double(Smolagents::Tool) }
      executor.send_tools(tools)
      expect(executor.send(:tools)).to eq(tools)
    end
  end

  describe "#send_variables" do
    it "stores variables" do
      executor = described_class.new
      variables = { "x" => 42 }
      executor.send_variables(variables)
      expect(executor.send(:variables)).to eq(variables)
    end
  end
end
