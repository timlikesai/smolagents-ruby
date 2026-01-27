require "spec_helper"
require "thor"
require "smolagents/cli/commands"
require "smolagents/cli/model_builder"

RSpec.describe Smolagents::CLI::Commands::Execute do
  let(:test_class) do
    Class.new do
      include Thor::Shell
      include Smolagents::CLI::ModelBuilder
      include Smolagents::CLI::Commands::Display
      include Smolagents::CLI::Commands::Execute

      attr_accessor :options

      def initialize
        @options = {}
      end
    end
  end

  let(:command) { test_class.new }
  let(:mock_model) { instance_double(Smolagents::OpenAIModel) }
  let(:mock_tool) { instance_double(Smolagents::Tool, description: "Test tool") }
  let(:mock_tool_class) do
    tool = mock_tool
    Class.new { define_singleton_method(:new) { tool } }
  end
  let(:final_answer_tool) { instance_double(Smolagents::Tool, description: "Final answer") }
  let(:final_answer_class) do
    tool = final_answer_tool
    Class.new { define_singleton_method(:new) { tool } }
  end
  let(:mock_agent) { instance_double(Smolagents::Agents::Agent, emit: nil) }
  let(:mock_timing) { double("timing", duration: 0.5) }
  let(:mock_result) do
    instance_double(
      Smolagents::RunResult,
      success?: true,
      output: "Result output",
      state: :success,
      steps: [],
      timing: mock_timing
    )
  end

  before do
    command.options = {
      provider: "openai",
      model: "gpt-4",
      api_key: "test-key",
      api_base: nil,
      tools: ["test_tool"],
      max_steps: 10,
      verbose: false,
      image: nil
    }

    allow(command).to receive(:build_model).and_return(mock_model)
    # Stub registry with both test_tool and final_answer (added by Smolagents.agent)
    stub_const("Smolagents::Tools::REGISTRY", {
                 "test_tool" => mock_tool_class,
                 "final_answer" => final_answer_class
               })
    allow(Smolagents::Agents::Agent).to receive(:new).and_return(mock_agent)
    allow(mock_agent).to receive(:run).and_return(mock_result)
  end

  describe "#run_task" do
    it "builds an agent and runs the task" do
      expect { command.run_task("Find Ruby docs") }.to output.to_stdout

      expect(mock_agent).to have_received(:run).with("Find Ruby docs", images: nil)
    end

    it "passes image option to agent run" do
      command.options[:image] = "/path/to/image.png"

      expect { command.run_task("Analyze image") }.to output.to_stdout

      expect(mock_agent).to have_received(:run).with("Analyze image", images: "/path/to/image.png")
    end

    it "displays running message" do
      expect { command.run_task("Test task") }.to output(/Running agent/).to_stdout
    end

    it "displays result after execution" do
      expect { command.run_task("Test task") }.to output(/Result/).to_stdout
    end
  end

  describe "#build_agent (private)" do
    it "creates agent with model from options" do
      expect { command.run_task("Test") }.to output.to_stdout

      expect(Smolagents::Agents::Agent).to have_received(:new) do |args|
        expect(args[:model]).to eq(mock_model)
      end
    end

    it "creates agent with tools from registry" do
      expect { command.run_task("Test") }.to output.to_stdout

      expect(Smolagents::Agents::Agent).to have_received(:new) do |args|
        expect(args[:tools]).to include(mock_tool)
      end
    end

    it "creates agent with max_steps from options" do
      command.options[:max_steps] = 20

      expect { command.run_task("Test") }.to output.to_stdout

      expect(Smolagents::Agents::Agent).to have_received(:new) do |args|
        expect(args[:config].max_steps).to eq(20)
      end
    end

    it "creates agent with logger" do
      expect { command.run_task("Test") }.to output.to_stdout

      expect(Smolagents::Agents::Agent).to have_received(:new) do |args|
        expect(args[:logger]).to be_a(Smolagents::Telemetry::AgentLogger)
      end
    end
  end

  describe "#build_tools (private)" do
    it "instantiates tools from registry" do
      expect { command.run_task("Test") }.to output.to_stdout

      expect(Smolagents::Agents::Agent).to have_received(:new) do |args|
        expect(args[:tools]).to include(mock_tool)
      end
    end

    it "raises Thor::Error for unknown tools" do
      command.options[:tools] = ["nonexistent"]

      expect { command.run_task("Test") }.to raise_error(Thor::Error, /Unknown tool: nonexistent/)
    end

    it "handles multiple tools" do
      tool2 = instance_double(Smolagents::Tool, description: "Another tool")
      tool2_class = Class.new { define_singleton_method(:new) { tool2 } }

      stub_const("Smolagents::Tools::REGISTRY", {
                   "test_tool" => mock_tool_class,
                   "other_tool" => tool2_class,
                   "final_answer" => final_answer_class
                 })
      command.options[:tools] = %w[test_tool other_tool]

      expect { command.run_task("Test") }.to output.to_stdout

      expect(Smolagents::Agents::Agent).to have_received(:new) do |args|
        expect(args[:tools]).to include(mock_tool)
        expect(args[:tools]).to include(tool2)
      end
    end
  end

  describe "#build_logger (private)" do
    it "returns AgentLogger with WARN level when not verbose" do
      command.options[:verbose] = false
      logger = command.send(:build_logger)

      expect(logger).to be_a(Smolagents::Telemetry::AgentLogger)
      expect(logger.level).to eq(Smolagents::Telemetry::AgentLogger::WARN)
    end

    it "returns AgentLogger with DEBUG level when verbose" do
      command.options[:verbose] = true
      logger = command.send(:build_logger)

      expect(logger.level).to eq(Smolagents::Telemetry::AgentLogger::DEBUG)
    end
  end
end
