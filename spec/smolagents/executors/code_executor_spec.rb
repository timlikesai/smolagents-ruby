RSpec.describe Smolagents::CodeExecutor do
  let(:executor) { described_class.new }

  describe "#supports?" do
    it "supports Ruby" do
      expect(executor.supports?(:ruby)).to be true
    end

    it "supports Python" do
      expect(executor.supports?(:python)).to be true
    end

    it "supports JavaScript" do
      expect(executor.supports?(:javascript)).to be true
    end

    it "supports TypeScript" do
      expect(executor.supports?(:typescript)).to be true
    end

    it "does not support unknown languages" do
      expect(executor.supports?(:cobol)).to be false
    end
  end

  describe "#execute with Ruby" do
    it "executes Ruby code" do
      result = executor.execute("2 + 2", language: :ruby)
      expect(result.success?).to be true
      expect(result.output).to eq(4)
    end

    it "validates Ruby code before execution" do
      result = executor.execute("system('ls')", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).to include("Dangerous")
    end

    it "uses LocalRubyExecutor by default" do
      expect(executor.executor_for(:ruby)).to be_a(Smolagents::LocalRubyExecutor)
    end

    it "uses RubyValidator" do
      expect(executor.validator_for(:ruby)).to be_a(Smolagents::RubyValidator)
    end
  end

  describe "#execute with Python" do
    it "uses DockerExecutor for Python" do
      expect(executor.executor_for(:python)).to be_a(Smolagents::DockerExecutor)
    end

    it "uses PythonValidator" do
      expect(executor.validator_for(:python)).to be_a(Smolagents::PythonValidator)
    end

    it "validates Python code" do
      result = executor.execute("os.system('ls')", language: :python)
      expect(result.failure?).to be true
      expect(result.error).to include("Dangerous")
    end
  end

  describe "#execute with JavaScript" do
    it "uses DockerExecutor for JavaScript" do
      expect(executor.executor_for(:javascript)).to be_a(Smolagents::DockerExecutor)
    end

    it "uses JavaScriptValidator" do
      expect(executor.validator_for(:javascript)).to be_a(Smolagents::JavaScriptValidator)
    end

    it "validates JavaScript code" do
      result = executor.execute("require('child_process')", language: :javascript)
      expect(result.failure?).to be true
      expect(result.error).to include("Dangerous")
    end
  end

  describe "#execute with TypeScript" do
    it "uses DockerExecutor for TypeScript" do
      expect(executor.executor_for(:typescript)).to be_a(Smolagents::DockerExecutor)
    end

    it "uses JavaScriptValidator for TypeScript" do
      expect(executor.validator_for(:typescript)).to be_a(Smolagents::JavaScriptValidator)
    end
  end

  describe "validation control" do
    it "validates by default" do
      result = executor.execute("eval('1')", language: :ruby)
      expect(result.failure?).to be true
    end

    it "can disable validation" do
      executor = described_class.new(validate: false)
      # This would normally fail validation, but should execute (and fail at runtime)
      result = executor.execute("this_will_fail", language: :ruby)
      expect(result.failure?).to be true
      expect(result.error).not_to include("Dangerous")
    end
  end

  describe "use_docker option" do
    it "uses LocalRubyExecutor by default for Ruby" do
      executor = described_class.new(use_docker: false)
      expect(executor.executor_for(:ruby)).to be_a(Smolagents::LocalRubyExecutor)
    end

    it "uses DockerExecutor for Ruby when use_docker: true" do
      executor = described_class.new(use_docker: true)
      expect(executor.executor_for(:ruby)).to be_a(Smolagents::DockerExecutor)
    end
  end

  describe "custom validators" do
    it "allows custom validators" do
      custom_validator = double("CustomValidator")
      allow(custom_validator).to receive(:validate!).and_return(true)

      executor = described_class.new(validators: { ruby: custom_validator })
      expect(executor.validator_for(:ruby)).to eq(custom_validator)
    end
  end

  describe "custom executors" do
    it "allows custom executors" do
      custom_executor = double("CustomExecutor")
      allow(custom_executor).to receive(:send_tools)
      allow(custom_executor).to receive(:send_variables)

      executor = described_class.new(executors: { ruby: custom_executor })
      expect(executor.executor_for(:ruby)).to eq(custom_executor)
    end
  end

  describe "#send_tools" do
    it "sends tools to all existing executors" do
      tool_mock = double("Tool")
      allow(tool_mock).to receive(:call).and_return("tool result")
      tools = { "test" => tool_mock }

      # Create an executor to populate cache
      executor.executor_for(:ruby)

      executor.send_tools(tools)

      # Verify tools were sent by calling the tool
      result = executor.execute("test", language: :ruby)
      expect(result.output).to eq("tool result")
    end

    it "sends tools to newly created executors" do
      tools = { "test" => double("Tool") }
      executor.send_tools(tools)

      # Create new executor after sending tools
      ruby_executor = executor.executor_for(:ruby)
      expect(ruby_executor.send(:tools)).to eq(tools)
    end
  end

  describe "#send_variables" do
    it "sends variables to all existing executors" do
      variables = { "x" => 42 }

      # Create an executor to populate cache
      executor.executor_for(:ruby)

      executor.send_variables(variables)

      # Verify variables were sent
      result = executor.execute("x", language: :ruby)
      expect(result.output).to eq(42)
    end

    it "sends variables to newly created executors" do
      variables = { "x" => 42 }
      executor.send_variables(variables)

      # Create new executor after sending variables
      ruby_executor = executor.executor_for(:ruby)
      expect(ruby_executor.send(:variables)).to eq(variables)
    end
  end

  describe "error handling" do
    it "raises ArgumentError for unsupported language" do
      expect do
        executor.execute("code", language: :unsupported)
      end.to raise_error(ArgumentError, /Unsupported language: unsupported/)
    end

    it "returns ExecutionResult on validation failure" do
      result = executor.execute("system('bad')", language: :ruby)
      expect(result).to be_a(Smolagents::Executor::ExecutionResult)
      expect(result.failure?).to be true
    end
  end

  describe "executor caching" do
    it "reuses executors for same language" do
      executor1 = executor.executor_for(:ruby)
      executor2 = executor.executor_for(:ruby)
      expect(executor1).to equal(executor2)
    end

    it "creates separate executors for different languages" do
      ruby_executor = executor.executor_for(:ruby)
      python_executor = executor.executor_for(:python)
      expect(ruby_executor).not_to equal(python_executor)
    end
  end

  describe "validator caching" do
    it "reuses validators for same language" do
      validator1 = executor.validator_for(:ruby)
      validator2 = executor.validator_for(:ruby)
      expect(validator1).to equal(validator2)
    end

    it "creates separate validators for different languages" do
      ruby_validator = executor.validator_for(:ruby)
      python_validator = executor.validator_for(:python)
      expect(ruby_validator).not_to equal(python_validator)
    end
  end
end
