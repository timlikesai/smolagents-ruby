require "thor"
require "smolagents/cli/commands"
require "smolagents/cli/model_builder"

RSpec.describe Smolagents::CLI::Commands do
  let(:test_class) do
    Class.new do
      include Thor::Shell
      include Smolagents::CLI::ModelBuilder
      include Smolagents::CLI::Commands

      attr_accessor :options

      def initialize
        @options = {}
      end
    end
  end

  let(:command) { test_class.new }

  describe "#run_task" do
    let(:mock_model) { instance_double(Smolagents::OpenAIModel) }
    let(:mock_tool) { instance_double(Smolagents::Tool, description: "A test tool") }
    let(:mock_tool_class) do
      tool_double = mock_tool
      Class.new do
        define_singleton_method(:new) { tool_double }
      end
    end
    let(:mock_agent) { instance_double(Smolagents::Agents::Code) }
    let(:mock_step) { double("step", step_number: 1) }
    let(:mock_timing) { double("timing", duration: 1.5) }
    let(:mock_result) do
      instance_double(
        Smolagents::RunResult,
        success?: true,
        output: "The answer is 42",
        state: :success,
        steps: [mock_step],
        timing: mock_timing
      )
    end

    before do
      command.options = {
        provider: "openai",
        model: "gpt-4",
        api_key: nil,
        api_base: nil,
        tools: ["final_answer"],
        agent_type: "code",
        max_steps: 10,
        verbose: false,
        image: nil
      }

      allow(command).to receive(:build_model).and_return(mock_model)
      stub_const("Smolagents::Tools::REGISTRY", { "final_answer" => mock_tool_class })
      allow(Smolagents::Agents::Code).to receive(:new).and_return(mock_agent)
      allow(mock_agent).to receive(:run).and_return(mock_result)
    end

    it "builds a model with provided options" do
      command.run_task("Test task")

      expect(command).to have_received(:build_model).with(
        provider: "openai",
        model_id: "gpt-4",
        api_key: nil,
        api_base: nil
      )
    end

    it "creates tools from registry" do
      command.run_task("Test task")

      # Verify the tool was passed to the agent
      expect(Smolagents::Agents::Code).to have_received(:new) do |args|
        expect(args[:tools]).to include(mock_tool)
      end
    end

    it "creates a Code agent for code agent_type" do
      command.run_task("Test task")

      expect(Smolagents::Agents::Code).to have_received(:new).with(
        tools: [mock_tool],
        model: mock_model,
        max_steps: 10,
        logger: kind_of(Object)
      )
    end

    it "creates a ToolCalling agent for tool_calling agent_type" do
      command.options[:agent_type] = "tool_calling"
      allow(Smolagents::Agents::ToolCalling).to receive(:new).and_return(mock_agent)

      command.run_task("Test task")

      expect(Smolagents::Agents::ToolCalling).to have_received(:new).with(
        tools: [mock_tool],
        model: mock_model,
        max_steps: 10,
        logger: kind_of(Object)
      )
    end

    it "runs the agent with the task and image option" do
      command.options[:image] = "/path/to/image.jpg"
      command.run_task("Test task")

      expect(mock_agent).to have_received(:run).with("Test task", images: "/path/to/image.jpg")
    end

    it "displays result when successful" do
      expect { command.run_task("Test task") }
        .to output(/Result:.*The answer is 42/m).to_stdout
    end

    it "displays step count and timing for successful result" do
      expect { command.run_task("Test task") }
        .to output(/1 steps.*1.5s/m).to_stdout
    end

    it "displays error message when result fails" do
      mock_result_fail = instance_double(
        Smolagents::RunResult,
        success?: false,
        state: :error,
        steps: []
      )
      allow(mock_agent).to receive(:run).and_return(mock_result_fail)

      expect { command.run_task("Test task") }
        .to output(/Agent did not complete successfully: error/m).to_stdout
    end

    it "displays last observation when steps exist" do
      step = double("step", observations: "Some observation text that should be truncated with more content here")
      mock_result_fail = instance_double(
        Smolagents::RunResult,
        success?: false,
        state: :max_steps_reached,
        steps: [step]
      )
      allow(mock_agent).to receive(:run).and_return(mock_result_fail)

      expect { command.run_task("Test task") }
        .to output(/Last observation:.*Some observation text/m).to_stdout
    end

    it "raises Thor::Error for unknown tool" do
      command.options[:tools] = ["unknown_tool"]

      expect { command.run_task("Test task") }
        .to raise_error(Thor::Error, /Unknown tool: unknown_tool/)
    end

    it "passes verbose logger when verbose option is true" do
      command.options[:verbose] = true
      command.run_task("Test task")

      # Verify that a logger was passed
      expect(Smolagents::Agents::Code).to have_received(:new) do |args|
        expect(args[:logger]).to be_a(Smolagents::AgentLogger)
      end
    end

    it "handles multiple tools" do
      tool2 = instance_double(Smolagents::Tool, description: "Another test tool")
      tool2_class = Class.new do
        define_singleton_method(:new) { tool2 }
      end

      stub_const("Smolagents::Tools::REGISTRY", {
                   "final_answer" => mock_tool_class,
                   "other_tool" => tool2_class
                 })
      command.options[:tools] = %w[final_answer other_tool]

      command.run_task("Test task")

      expect(Smolagents::Agents::Code).to have_received(:new) do |args|
        expect(args[:tools]).to contain_exactly(mock_tool, tool2)
      end
    end
  end

  describe "#tools" do
    before do
      tool_instance = instance_double(Smolagents::Tool, description: "A test tool")
      tool_class = Class.new do
        define_singleton_method(:new) { tool_instance }
      end
      stub_const("Smolagents::Tools::REGISTRY", {
                   "final_answer" => Smolagents::FinalAnswerTool,
                   "ruby_interpreter" => tool_class
                 })
    end

    it "lists available tools" do
      expect { command.tools }.to output(/Available tools/).to_stdout
    end

    it "shows tool names" do
      expect { command.tools }.to output(/final_answer/).to_stdout
    end

    it "shows tool descriptions" do
      expect { command.tools }.to output(/final_answer/).to_stdout
    end

    it "formats tool names with green color" do
      allow(command).to receive(:say)
      command.tools

      expect(command).to have_received(:say).with("Available tools:", :cyan)
      expect(command).to have_received(:say).with("\n  final_answer", :green)
    end

    it "indents tool descriptions" do
      allow(command).to receive(:say)
      command.tools

      # Verify that at least some calls are indented with 4 spaces (tool descriptions)
      expect(command).to have_received(:say).with(match(/^\s{4}\S/), any_args).at_least(:once)
    end

    it "handles tools with no description gracefully" do
      tool_class = Class.new do
        def description
          ""
        end
      end

      stub_const("Smolagents::Tools::REGISTRY", { "empty_tool" => tool_class })

      expect { command.tools }.not_to raise_error
    end

    it "iterates through all registry tools" do
      allow(command).to receive(:say)
      command.tools

      expect(command).to have_received(:say).at_least(3).times
    end
  end

  describe "#models" do
    it "lists model providers" do
      expect { command.models }.to output(/Model providers/).to_stdout
    end

    it "shows OpenAI examples" do
      expect { command.models }.to output(/OpenAI/).to_stdout
    end

    it "shows OpenAI models" do
      expect { command.models }.to output(/gpt-4/).to_stdout
      expect { command.models }.to output(/gpt-3.5-turbo/).to_stdout
    end

    it "shows Anthropic examples" do
      expect { command.models }.to output(/Anthropic/).to_stdout
    end

    it "shows Anthropic models" do
      expect { command.models }.to output(/claude-3-5-sonnet-20241022/).to_stdout
    end

    it "shows local LM Studio examples" do
      expect { command.models }.to output(/Local \(LM Studio\)/).to_stdout
      expect { command.models }.to output(%r{http://localhost:1234/v1}).to_stdout
    end

    it "shows local Ollama examples" do
      expect { command.models }.to output(/Local \(Ollama\)/).to_stdout
      expect { command.models }.to output(%r{http://localhost:11434/v1}).to_stdout
    end

    it "calls print_provider_examples for each provider" do
      allow(command).to receive(:print_provider_examples)
      command.models

      expect(command).to have_received(:print_provider_examples).with(
        "OpenAI",
        ["--provider openai --model gpt-4", "--provider openai --model gpt-3.5-turbo"]
      )

      expect(command).to have_received(:print_provider_examples).with(
        "Anthropic",
        ["--provider anthropic --model claude-3-5-sonnet-20241022"]
      )

      expect(command).to have_received(:print_provider_examples).with(
        "Local (LM Studio)",
        ["--provider openai --model local-model --api-base http://localhost:1234/v1"]
      )

      expect(command).to have_received(:print_provider_examples).with(
        "Local (Ollama)",
        ["--provider openai --model llama3 --api-base http://localhost:11434/v1"]
      )
    end
  end

  describe "#print_provider_examples" do
    it "prints provider name in green" do
      allow(command).to receive(:say)
      command.print_provider_examples("TestProvider", [])

      expect(command).to have_received(:say).with("\n  TestProvider:", :green)
    end

    it "prints each example" do
      allow(command).to receive(:say)
      examples = ["--example 1", "--example 2"]
      command.print_provider_examples("TestProvider", examples)

      examples.each do |ex|
        expect(command).to have_received(:say).with("    #{ex}")
      end
    end

    it "handles empty examples array" do
      allow(command).to receive(:say)
      command.print_provider_examples("TestProvider", [])

      expect(command).to have_received(:say).with("\n  TestProvider:", :green)
    end

    it "formats output with proper indentation" do
      allow(command).to receive(:say)
      command.print_provider_examples("MyProvider", ["--option value"])

      expect(command).to have_received(:say).with("    --option value")
    end
  end

  describe "#build_logger" do
    it "returns an AgentLogger" do
      command.options = { verbose: false }
      logger = command.send(:build_logger)

      expect(logger).to be_a(Smolagents::AgentLogger)
    end

    it "sets debug level when verbose is true" do
      command.options = { verbose: true }
      logger = command.send(:build_logger)

      expect(logger.level).to eq(Smolagents::AgentLogger::DEBUG)
    end

    it "sets warn level when verbose is false" do
      command.options = { verbose: false }
      logger = command.send(:build_logger)

      expect(logger.level).to eq(Smolagents::AgentLogger::WARN)
    end

    it "writes to stderr" do
      command.options = { verbose: false }
      allow(Smolagents::AgentLogger).to receive(:new).and_call_original

      command.send(:build_logger)

      expect(Smolagents::AgentLogger).to have_received(:new).with(
        output: $stderr,
        level: Smolagents::AgentLogger::WARN
      )
    end
  end

  describe "Integration: run_task with build_logger" do
    let(:mock_model) { instance_double(Smolagents::OpenAIModel) }
    let(:mock_tool) { instance_double(Smolagents::Tool, description: "A test tool") }
    let(:mock_tool_class) do
      tool_double = mock_tool
      Class.new do
        define_singleton_method(:new) { tool_double }
      end
    end
    let(:mock_agent) { instance_double(Smolagents::Agents::Code) }
    let(:mock_timing) { double("timing", duration: 0.5) }
    let(:mock_result) do
      instance_double(
        Smolagents::RunResult,
        success?: true,
        output: "Success",
        state: :success,
        steps: [],
        timing: mock_timing
      )
    end

    before do
      command.options = {
        provider: "openai",
        model: "gpt-4",
        api_key: nil,
        api_base: nil,
        tools: ["final_answer"],
        agent_type: "code",
        max_steps: 10,
        verbose: true,
        image: nil
      }

      allow(command).to receive(:build_model).and_return(mock_model)
      stub_const("Smolagents::Tools::REGISTRY", { "final_answer" => mock_tool_class })
      allow(Smolagents::Agents::Code).to receive(:new).and_return(mock_agent)
      allow(mock_agent).to receive(:run).and_return(mock_result)
    end

    it "passes verbose logger to agent" do
      command.run_task("Test task")

      expect(Smolagents::Agents::Code).to have_received(:new) do |args|
        expect(args[:logger].level).to eq(Smolagents::AgentLogger::DEBUG)
      end
    end

    it "passes quiet logger to agent when not verbose" do
      command.options[:verbose] = false
      command.run_task("Test task")

      expect(Smolagents::Agents::Code).to have_received(:new) do |args|
        expect(args[:logger].level).to eq(Smolagents::AgentLogger::WARN)
      end
    end
  end

  describe "Error handling in run_task" do
    let(:mock_model) { instance_double(Smolagents::OpenAIModel) }

    before do
      command.options = {
        provider: "openai",
        model: "gpt-4",
        api_key: nil,
        api_base: nil,
        tools: ["final_answer"],
        agent_type: "code",
        max_steps: 10,
        verbose: false,
        image: nil
      }

      allow(command).to receive(:build_model).and_return(mock_model)
    end

    it "handles Thor::Error from unknown tool" do
      stub_const("Smolagents::Tools::REGISTRY", {})
      command.options[:tools] = ["nonexistent"]

      expect { command.run_task("Test") }.to raise_error(Thor::Error, /Unknown tool/)
    end

    it "propagates agent execution errors" do
      tool = instance_double(Smolagents::Tool, description: "A test tool")
      tool_class = Class.new do
        define_singleton_method(:new) { tool }
      end
      stub_const("Smolagents::Tools::REGISTRY", { "final_answer" => tool_class })

      allow(Smolagents::Agents::Code).to receive(:new).and_raise(RuntimeError, "Agent setup failed")

      expect { command.run_task("Test") }.to raise_error(RuntimeError, /Agent setup failed/)
    end
  end
end
