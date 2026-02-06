require "spec_helper"

RSpec.describe Smolagents::Builders::ToolResolution do
  include_context "with mocked tools"

  let(:test_builder_class) do
    Class.new(Data.define(:configuration)) do
      include Smolagents::Builders::ToolResolution

      def self.create
        new(configuration: { tool_names: [], tool_instances: [], spawn_config: nil })
      end

      def resolve_model
        Object.new
      end
    end
  end

  let(:builder) { test_builder_class.create }

  describe "#resolve_tools" do
    context "with tool names" do
      it "resolves tool names from registry" do
        config = test_builder_class.new(
          configuration: {
            tool_names: [:google_search],
            tool_instances: [],
            spawn_config: nil
          }
        )

        tools = config.send(:resolve_tools)

        expect(tools).to include(mock_search_tool)
      end

      it "resolves multiple tool names" do
        config = test_builder_class.new(
          configuration: {
            tool_names: %i[google_search web_search],
            tool_instances: [],
            spawn_config: nil
          }
        )

        tools = config.send(:resolve_tools)

        expect(tools.size).to eq(2)
      end

      it "raises error for unknown tool name" do
        config = test_builder_class.new(
          configuration: {
            tool_names: [:unknown_tool],
            tool_instances: [],
            spawn_config: nil
          }
        )

        expect { config.send(:resolve_tools) }
          .to raise_error(ArgumentError, /Unknown tool.*unknown_tool/)
      end

      it "suggests similar tools with Did You Mean for typos" do
        config = test_builder_class.new(
          configuration: {
            tool_names: [:google_serch],
            tool_instances: [],
            spawn_config: nil
          }
        )

        expect { config.send(:resolve_tools) }
          .to raise_error(ArgumentError, /Did you mean.*google_search/)
      end

      it "shows available tools when no similar matches exist" do
        config = test_builder_class.new(
          configuration: {
            tool_names: [:xyz_completely_different],
            tool_instances: [],
            spawn_config: nil
          }
        )

        expect { config.send(:resolve_tools) }
          .to raise_error(ArgumentError, /Available.*google_search/)
      end
    end

    context "with tool instances" do
      it "includes tool instances in resolved tools" do
        tool = instance_double(Smolagents::Tools::Tool)
        config = test_builder_class.new(
          configuration: {
            tool_names: [],
            tool_instances: [tool],
            spawn_config: nil
          }
        )

        tools = config.send(:resolve_tools)

        expect(tools).to include(tool)
      end

      it "preserves tool instance order" do
        tool1 = instance_double(Smolagents::Tools::Tool)
        tool2 = instance_double(Smolagents::Tools::Tool)

        config = test_builder_class.new(
          configuration: {
            tool_names: [],
            tool_instances: [tool1, tool2],
            spawn_config: nil
          }
        )

        tools = config.send(:resolve_tools)

        expect(tools[0]).to eq(tool1)
        expect(tools[1]).to eq(tool2)
      end
    end

    context "with mixed names and instances" do
      it "combines resolved names and instances" do
        custom_tool = instance_double(Smolagents::Tools::Tool)
        config = test_builder_class.new(
          configuration: {
            tool_names: [:google_search],
            tool_instances: [custom_tool],
            spawn_config: nil
          }
        )

        tools = config.send(:resolve_tools)

        expect(tools).to include(mock_search_tool)
        expect(tools).to include(custom_tool)
      end

      it "resolves names before instances in order" do
        custom_tool = instance_double(Smolagents::Tools::Tool)
        config = test_builder_class.new(
          configuration: {
            tool_names: [:google_search],
            tool_instances: [custom_tool],
            spawn_config: nil
          }
        )

        tools = config.send(:resolve_tools)

        # Registry tools should come before instances
        expect(tools.first).to eq(mock_search_tool)
        expect(tools.last).to eq(custom_tool)
      end
    end

    context "with spawn_config" do
      it "adds spawn tool when spawn_config is enabled" do
        spawn_config = Smolagents::Types::SpawnConfig.create(max_children: 1)

        config = test_builder_class.new(
          configuration: {
            tool_names: [],
            tool_instances: [],
            spawn_config:
          }
        )

        tools = config.send(:resolve_tools)

        expect(tools.size).to eq(1)
        expect(tools.first).to be_a(Smolagents::Tools::SpawnAgentTool)
      end

      it "does not add spawn tool when spawn_config is disabled" do
        spawn_config = Smolagents::Types::SpawnConfig.create(max_children: 0)

        config = test_builder_class.new(
          configuration: {
            tool_names: [],
            tool_instances: [],
            spawn_config:
          }
        )

        tools = config.send(:resolve_tools)

        expect(tools).to be_empty
      end

      it "combines base tools with spawn tool" do
        custom_tool = instance_double(Smolagents::Tools::Tool, is_a?: false)
        spawn_config = Smolagents::Types::SpawnConfig.create(max_children: 1)

        config = test_builder_class.new(
          configuration: {
            tool_names: [:google_search],
            tool_instances: [custom_tool],
            spawn_config:
          }
        )

        tools = config.send(:resolve_tools)

        expect(tools).to include(mock_search_tool)
        expect(tools).to include(custom_tool)
        expect(tools.last).to be_a(Smolagents::Tools::SpawnAgentTool)
      end
    end

    context "empty configuration" do
      it "returns empty array when no tools configured" do
        tools = builder.send(:resolve_tools)

        expect(tools).to eq([])
      end
    end
  end

  describe "#partition_tool_args" do
    it "partitions symbols as names" do
      names, instances = builder.send(:partition_tool_args, %i[search web])

      expect(names).to eq(%i[search web])
      expect(instances).to be_empty
    end

    it "partitions strings as names" do
      names, instances = builder.send(:partition_tool_args, %w[search web])

      expect(names).to eq(%w[search web])
      expect(instances).to be_empty
    end

    it "partitions instances separately" do
      tool1 = instance_double(Smolagents::Tools::Tool)
      tool2 = instance_double(Smolagents::Tools::Tool)

      names, instances = builder.send(:partition_tool_args, [tool1, tool2])

      expect(names).to be_empty
      expect(instances).to eq([tool1, tool2])
    end

    it "partitions mixed arguments" do
      tool = instance_double(Smolagents::Tools::Tool)

      names, instances = builder.send(:partition_tool_args, [:search, tool, :web, tool])

      expect(names).to eq(%i[search web])
      expect(instances).to eq([tool, tool])
    end

    it "preserves order within each partition" do
      tool1 = instance_double(Smolagents::Tools::Tool)
      tool2 = instance_double(Smolagents::Tools::Tool)

      names, instances = builder.send(:partition_tool_args, [:z, tool1, :a, tool2, :m])

      expect(names).to eq(%i[z a m])
      expect(instances).to eq([tool1, tool2])
    end
  end

  describe "#expand_toolkits" do
    before do
      allow(Smolagents::Toolkits).to receive(:toolkit?)
        .and_call_original
      allow(Smolagents::Toolkits).to receive(:toolkit?)
        .with(:search_toolkit)
        .and_return(true)
      allow(Smolagents::Toolkits).to receive(:get)
        .with(:search_toolkit)
        .and_return(%i[google_search])
      allow(Smolagents::Toolkits).to receive(:toolkit?)
        .with(:web_toolkit)
        .and_return(true)
      allow(Smolagents::Toolkits).to receive(:get)
        .with(:web_toolkit)
        .and_return(%i[web_search visit_webpage])
    end

    it "expands toolkit names" do
      expanded = builder.send(:expand_toolkits, [:search_toolkit])

      expect(expanded).to eq(%i[google_search])
    end

    it "preserves non-toolkit names" do
      expanded = builder.send(:expand_toolkits, [:google_search])

      expect(expanded).to eq([:google_search])
    end

    it "expands multiple toolkits" do
      expanded = builder.send(:expand_toolkits, %i[search_toolkit web_toolkit])

      expect(expanded).to eq(%i[google_search web_search visit_webpage])
    end

    it "mixes toolkits and individual tools" do
      expanded = builder.send(:expand_toolkits, %i[search_toolkit custom_tool web_toolkit])

      expect(expanded).to include(:google_search, :custom_tool, :web_search, :visit_webpage)
    end

    it "converts strings to symbols" do
      expanded = builder.send(:expand_toolkits, ["search_toolkit"])

      expect(expanded.all?(Symbol)).to be true
    end

    context "empty input" do
      it "returns empty array for empty input" do
        expanded = builder.send(:expand_toolkits, [])

        expect(expanded).to eq([])
      end
    end
  end

  describe "#build_spawn_tool" do
    it "creates SpawnAgentTool from spawn_config" do
      spawn_config = instance_double(Smolagents::Types::SpawnConfig)
      config = test_builder_class.new(
        configuration: {
          tool_names: [],
          tool_instances: [],
          spawn_config:
        }
      )

      spawn_tool = config.send(:build_spawn_tool, spawn_config)

      expect(spawn_tool).to be_a(Smolagents::Tools::SpawnAgentTool)
    end

    it "passes parent model to spawn tool" do
      spawn_config = instance_double(Smolagents::Types::SpawnConfig)
      config = test_builder_class.new(
        configuration: {
          tool_names: [],
          tool_instances: [],
          spawn_config:
        }
      )

      spawn_tool = config.send(:build_spawn_tool, spawn_config)

      expect(spawn_tool.instance_variable_get(:@parent_model)).not_to be_nil
    end

    it "passes spawn_config to spawn tool" do
      spawn_config = instance_double(Smolagents::Types::SpawnConfig)
      config = test_builder_class.new(
        configuration: {
          tool_names: [],
          tool_instances: [],
          spawn_config:
        }
      )

      spawn_tool = config.send(:build_spawn_tool, spawn_config)

      expect(spawn_tool.instance_variable_get(:@spawn_config)).to eq(spawn_config)
    end

    it "includes inline tools in spawn tool" do
      inline_tool = instance_double(Smolagents::Tools::InlineTool)
      allow(inline_tool).to receive(:is_a?).with(Smolagents::Tools::InlineTool).and_return(true)
      spawn_config = instance_double(Smolagents::Types::SpawnConfig)

      config = test_builder_class.new(
        configuration: {
          tool_names: [],
          tool_instances: [inline_tool],
          spawn_config:
        }
      )

      spawn_tool = config.send(:build_spawn_tool, spawn_config)

      expect(spawn_tool.instance_variable_get(:@inline_tools)).to include(inline_tool)
    end
  end

  describe "#raise_unknown_tool!" do
    it "raises ArgumentError with tool name" do
      config = test_builder_class.new(
        configuration: {
          tool_names: [:missing],
          tool_instances: [],
          spawn_config: nil
        }
      )

      expect { config.send(:raise_unknown_tool!, :missing) }
        .to raise_error(ArgumentError, /Unknown tool: missing/)
    end

    it "includes available tools in error message" do
      config = test_builder_class.new(
        configuration: {
          tool_names: [:missing],
          tool_instances: [],
          spawn_config: nil
        }
      )

      expect { config.send(:raise_unknown_tool!, :missing) }
        .to raise_error(ArgumentError, /Available:/)
    end
  end
end
