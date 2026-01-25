require "smolagents/concerns/agents/specialized/class_methods"

RSpec.describe Smolagents::Concerns::Specialized::ClassMethods do
  let(:test_class) do
    Class.new do
      extend Smolagents::Concerns::Specialized::ClassMethods
    end
  end

  describe "#instructions" do
    it "sets the specialized instructions" do
      test_class.instructions("Be helpful and concise")
      expect(test_class.specialized_instructions).to eq("Be helpful and concise")
    end

    it "freezes the instructions string" do
      instructions_text = "Be helpful and concise"
      test_class.instructions(instructions_text)

      expect(test_class.specialized_instructions).to be_frozen
    end

    it "accepts heredoc text" do
      heredoc = <<~TEXT
        You are a specialized assistant.
        Be helpful and professional.
      TEXT

      test_class.instructions(heredoc)
      expect(test_class.specialized_instructions).to be_a(String)
      expect(test_class.specialized_instructions).not_to be_empty
    end

    it "returns the frozen instructions" do
      result = test_class.instructions("Test instructions")
      expect(result).to be_frozen
      expect(result).to eq("Test instructions")
    end

    it "overwrites previous instructions" do
      test_class.instructions("First instructions")
      test_class.instructions("Second instructions")

      expect(test_class.specialized_instructions).to eq("Second instructions")
    end
  end

  describe "#specialized_instructions" do
    context "when instructions have been set" do
      before do
        test_class.instructions("Custom instructions")
      end

      it "returns the instructions" do
        expect(test_class.specialized_instructions).to eq("Custom instructions")
      end
    end

    context "when instructions have not been set" do
      it "returns nil" do
        expect(test_class.specialized_instructions).to be_nil
      end
    end
  end

  describe "#default_tools with tool names" do
    it "stores tool names as symbol array" do
      test_class.default_tools(:search, :web)

      expect(test_class.default_tool_names).to eq(%i[search web])
    end

    it "accepts single tool name" do
      test_class.default_tools(:search)

      expect(test_class.default_tool_names).to eq(%i[search])
    end

    it "accepts multiple tool names" do
      test_class.default_tools(:search, :file_write, :execute)

      expect(test_class.default_tool_names).to eq(%i[search file_write execute])
    end

    it "flattens array arguments" do
      tools = %i[search parse]
      test_class.default_tools(tools)

      expect(test_class.default_tool_names).to eq(%i[search parse])
    end

    it "overwrites previous tool names" do
      test_class.default_tools(:search)
      test_class.default_tools(:web)

      expect(test_class.default_tool_names).to eq(%i[web])
    end

    it "stores as instance variable" do
      test_class.default_tools(:search)
      expect(test_class.instance_variable_get(:@default_tool_names)).to eq(%i[search])
    end
  end

  describe "#default_tools with block" do
    it "stores a callable block" do
      block = proc { |_opts| [] }
      test_class.default_tools(&block)

      expect(test_class.default_tools_block).to be_a(Proc)
    end

    it "accepts options in block parameter" do
      test_class.default_tools do |options|
        expect(options).to be_a(Hash)
        []
      end

      expect(test_class.default_tools_block).to be_a(Proc)
    end

    it "block can return array of tools" do
      block = proc do |_opts|
        [double("tool1"), double("tool2")]
      end
      test_class.default_tools(&block)

      tools = test_class.default_tools_block.call({})
      expect(tools.length).to eq(2)
    end

    it "overwrites previous block" do
      test_class.default_tools { |_| [:first] }
      test_class.default_tools { |_| [:second] }

      result = test_class.default_tools_block.call({})
      expect(result).to eq([:second])
    end
  end

  describe "#default_tool_names" do
    context "when tool names are set" do
      before do
        test_class.default_tools(:search, :parse)
      end

      it "returns the tool names" do
        expect(test_class.default_tool_names).to eq(%i[search parse])
      end
    end

    context "when tool names are not set" do
      it "returns nil" do
        expect(test_class.default_tool_names).to be_nil
      end
    end
  end

  describe "#default_tools_block" do
    context "when a block is set" do
      before do
        test_class.default_tools { |_| [] }
      end

      it "returns the proc" do
        expect(test_class.default_tools_block).to be_a(Proc)
      end
    end

    context "when no block is set" do
      it "returns nil" do
        expect(test_class.default_tools_block).to be_nil
      end
    end
  end

  describe "DSL integration" do
    it "supports chaining instructions and tools" do
      test_class.instructions("Be helpful")
      test_class.default_tools(:search, :parse)

      expect(test_class.specialized_instructions).to eq("Be helpful")
      expect(test_class.default_tool_names).to eq(%i[search parse])
    end

    it "supports class with both block and instructions" do
      test_class.instructions("Instructions")
      test_class.default_tools { |_| [:dynamic_tool] }

      expect(test_class.specialized_instructions).to eq("Instructions")
      expect(test_class.default_tools_block).not_to be_nil
    end

    it "allows empty tool list" do
      test_class.default_tools

      expect(test_class.default_tool_names).to eq([])
    end
  end

  describe "immutability" do
    it "instructions string is frozen" do
      test_class.instructions("Frozen instructions")
      expect(test_class.specialized_instructions).to be_frozen
    end

    it "prevents mutation of frozen instructions" do
      test_class.instructions("Original")
      instructions = test_class.specialized_instructions

      expect do
        instructions << " Modified"
      end.to raise_error(FrozenError)
    end
  end

  describe "inheritance" do
    let(:parent_class) do
      Class.new do
        extend Smolagents::Concerns::Specialized::ClassMethods
      end
    end

    let(:child_class) do
      Class.new(parent_class)
    end

    it "child can override parent instructions" do
      parent_class.instructions("Parent instructions")
      child_class.instructions("Child instructions")

      expect(parent_class.specialized_instructions).to eq("Parent instructions")
      expect(child_class.specialized_instructions).to eq("Child instructions")
    end

    it "child can override parent tools" do
      parent_class.default_tools(:search)
      child_class.default_tools(:web)

      expect(parent_class.default_tool_names).to eq(%i[search])
      expect(child_class.default_tool_names).to eq(%i[web])
    end
  end
end
