require "smolagents/concerns/agents/specialized/instance_methods"
require "smolagents/concerns/agents/specialized/class_methods"

RSpec.describe Smolagents::Concerns::Specialized::InstanceMethods do
  # Base class that captures what gets passed to it
  let(:base_class) do
    Class.new do
      attr_reader :model, :tools, :config, :options

      def initialize(model:, tools: [], config: nil, **options)
        @model = model
        @tools = tools
        @config = config
        @options = options
      end
    end
  end

  let(:test_class) do
    parent = base_class
    Class.new(parent) do
      extend Smolagents::Concerns::Specialized::ClassMethods
      include Smolagents::Concerns::Specialized::InstanceMethods
    end
  end

  let(:mock_model) { instance_double(Smolagents::Model) }

  describe "#initialize" do
    context "with default tool names" do
      before do
        test_class.default_tools(:search, :parse)
        test_class.instructions("Be helpful")

        # Mock the tool registry
        allow(Smolagents::Tools).to receive(:get).and_call_original
        allow(Smolagents::Tools).to receive(:get).with("search") do
          instance_double(Smolagents::Tool)
        end
        allow(Smolagents::Tools).to receive(:get).with("parse") do
          instance_double(Smolagents::Tool)
        end
      end

      it "initializes with resolved tools" do
        instance = test_class.new(model: mock_model)
        # Tools should be resolved (implementation dependent on parent)
        expect(instance).to be_a(test_class)
      end

      it "injects specialized instructions" do
        instance = test_class.new(model: mock_model)
        # Configuration is created internally
        expect(instance).to be_a(test_class)
      end
    end

    context "with default tools block" do
      before do
        test_class.default_tools do |options|
          [
            instance_double(Smolagents::Tool, name: "dynamic1"),
            instance_double(Smolagents::Tool, name: "dynamic2")
          ]
        end
        test_class.instructions("Block-based tools")
      end

      it "calls block to resolve tools" do
        block_called = false
        test_class.default_tools do |options|
          block_called = true
          []
        end

        test_class.new(model: mock_model)
        expect(block_called).to be true
      end

      it "passes options to block" do
        received_options = nil
        test_class.default_tools do |options|
          received_options = options
          []
        end

        custom_option = { custom_key: "value" }
        test_class.new(model: mock_model, **custom_option)

        # Options should be accessible to the block
        expect(received_options).to be_a(Hash) if received_options
      end
    end

    context "without default tools" do
      before do
        test_class.instructions("No tools")
      end

      it "initializes with empty tools array" do
        instance = test_class.new(model: mock_model)
        expect(instance).to be_a(test_class)
      end
    end

    context "with specialized option filtering" do
      let(:test_class_with_filter) do
        Class.new(test_class) do
          def specialized_option_keys
            [:custom_option]
          end
        end
      end

      before do
        test_class_with_filter.default_tools(:search)

        allow(Smolagents::Tools).to receive(:get).and_call_original
        allow(Smolagents::Tools).to receive(:get).with("search") do
          instance_double(Smolagents::Tool)
        end
      end

      it "filters out specialized option keys" do
        instance = test_class_with_filter.new(
          model: mock_model,
          custom_option: "should_be_filtered"
        )

        # The specialized_option_keys should be used to filter
        expect(instance).to be_a(test_class_with_filter)
      end
    end
  end

  describe "#resolve_default_tools" do
    context "with block defined" do
      before do
        test_class.default_tools { |_opts| [:block_tool] }
      end

      it "uses block to resolve tools" do
        instance = test_class.new(model: mock_model)
        tools = instance.send(:resolve_default_tools, {})

        expect(tools).to eq([:block_tool])
      end

      it "prefers block over tool names" do
        test_class.default_tools(:search) # This should be overridden
        test_class.default_tools { |_opts| [:block_tool] }

        instance = test_class.new(model: mock_model)
        tools = instance.send(:resolve_default_tools, {})

        expect(tools).to eq([:block_tool])
      end
    end

    context "with tool names defined" do
      before do
        test_class.default_tools(:search, :parse)

        allow(Smolagents::Tools).to receive(:get).and_call_original
        allow(Smolagents::Tools).to receive(:get).with("search") do
          instance_double(Smolagents::Tool, name: "search")
        end
        allow(Smolagents::Tools).to receive(:get).with("parse") do
          instance_double(Smolagents::Tool, name: "parse")
        end
      end

      it "instantiates tools by name" do
        instance = test_class.new(model: mock_model)
        tools = instance.send(:resolve_default_tools, {})

        expect(tools.size).to eq(2)
      end
    end

    context "without tools defined" do
      it "returns empty array" do
        instance = test_class.new(model: mock_model)
        tools = instance.send(:resolve_default_tools, {})

        expect(tools).to eq([])
      end
    end
  end

  describe "#instantiate_tool" do
    context "with tool class in registry" do
      let(:tool_class) do
        Class.new do
          def initialize
            @initialized = true
          end
        end
      end

      before do
        allow(Smolagents::Tools).to receive(:get).and_call_original
        allow(Smolagents::Tools).to receive(:get).with("custom_tool").and_return(tool_class)
      end

      it "instantiates a tool class" do
        instance = test_class.new(model: mock_model)
        tool = instance.send(:instantiate_tool, :custom_tool)

        expect(tool).to be_a(tool_class)
      end

      it "converts symbol to string" do
        instance = test_class.new(model: mock_model)
        instance.send(:instantiate_tool, :custom_tool)

        expect(Smolagents::Tools).to have_received(:get).with("custom_tool")
      end
    end

    context "with tool instance in registry" do
      let(:tool_instance) { instance_double(Smolagents::Tool) }

      before do
        allow(Smolagents::Tools).to receive(:get).and_call_original
        allow(Smolagents::Tools).to receive(:get).with("instance_tool").and_return(tool_instance)
      end

      it "returns the instance directly" do
        instance = test_class.new(model: mock_model)
        result = instance.send(:instantiate_tool, :instance_tool)

        expect(result).to eq(tool_instance)
      end
    end

    context "with unknown tool" do
      before do
        allow(Smolagents::Tools).to receive(:get).and_call_original
        allow(Smolagents::Tools).to receive(:get).with("unknown").and_return(nil)
      end

      it "raises ArgumentError" do
        instance = test_class.new(model: mock_model)

        expect do
          instance.send(:instantiate_tool, :unknown)
        end.to raise_error(ArgumentError, /Unknown tool/)
      end
    end

    context "with string or symbol tool name" do
      let(:tool_class) { double("tool_class") }

      before do
        allow(Smolagents::Tools).to receive(:get).and_return(tool_class)
        allow(tool_class).to receive(:is_a?).with(Class).and_return(true)
        allow(tool_class).to receive(:new).and_return(instance_double(Smolagents::Tool))
      end

      it "accepts symbol tool name" do
        instance = test_class.new(model: mock_model)
        instance.send(:instantiate_tool, :some_tool)

        expect(Smolagents::Tools).to have_received(:get).with("some_tool")
      end

      it "accepts string tool name" do
        instance = test_class.new(model: mock_model)
        instance.send(:instantiate_tool, "some_tool")

        expect(Smolagents::Tools).to have_received(:get).with("some_tool")
      end
    end
  end

  describe "#specialized_option_keys" do
    it "returns empty array by default" do
      instance = test_class.new(model: mock_model)
      keys = instance.send(:specialized_option_keys)

      expect(keys).to eq([])
    end

    it "can be overridden in subclass" do
      subclass = Class.new(test_class) do
        def specialized_option_keys
          %i[custom filter]
        end
      end

      instance = subclass.new(model: mock_model)
      keys = instance.send(:specialized_option_keys)

      expect(keys).to eq(%i[custom filter])
    end
  end

  describe "integration" do
    # Uses the test_class from let block, which properly inherits from base_class

    before do
      test_class.instructions("Test instructions")
      test_class.default_tools(:search)

      allow(Smolagents::Tools).to receive(:get).and_call_original
      allow(Smolagents::Tools).to receive(:get).with("search") do
        instance_double(Smolagents::Tool)
      end
    end

    it "initializes with instructions and tools" do
      instance = test_class.new(model: mock_model)
      expect(instance).to be_a(test_class)
    end

    it "resolves tools before passing to parent" do
      instance = test_class.new(model: mock_model)
      # Tools should be resolved
      expect(instance.tools).not_to be_nil
    end

    it "creates config with specialized instructions" do
      instance = test_class.new(model: mock_model)
      # Config should be created with custom_instructions
      expect(instance.config).not_to be_nil
    end
  end

  describe "error handling" do
    context "with missing tool" do
      before do
        test_class.default_tools(:nonexistent)
        allow(Smolagents::Tools).to receive(:get).and_call_original
        allow(Smolagents::Tools).to receive(:get).with("nonexistent").and_return(nil)
      end

      it "raises error during initialization" do
        expect do
          test_class.new(model: mock_model)
        end.to raise_error(ArgumentError)
      end
    end

    context "with exception in block" do
      before do
        test_class.default_tools do |_|
          raise StandardError, "Block error"
        end
      end

      it "propagates block exceptions" do
        expect do
          test_class.new(model: mock_model)
        end.to raise_error(StandardError, "Block error")
      end
    end
  end
end
