RSpec.describe Smolagents::Testing::ToolExecutionTests do
  describe "constants" do
    it "defines all capability names" do
      expect(described_class::CAPABILITIES).to contain_exactly(
        :variable_persistence,
        :sequential_tools,
        :parallel_tools,
        :error_recovery,
        :result_synthesis
      )
    end
  end

  describe ".register_capabilities!" do
    it "registers all capability tests" do
      # The capabilities should already be registered on module load
      registered_capabilities = Smolagents::Testing::Capabilities.capabilities

      expect(registered_capabilities).to include(*described_class::CAPABILITIES)
    end
  end

  describe ".all_tests" do
    it "returns all tests across all capabilities" do
      all_tests = described_class.all_tests

      expect(all_tests).to be_an(Array)
      expect(all_tests).not_to be_empty
    end

    it "includes tests from each capability" do
      described_class.all_tests

      # Each capability should have at least one test
      described_class::CAPABILITIES.each do |capability|
        capability_tests = Smolagents::Testing::Capabilities.for_capability(capability)
        expect(capability_tests).not_to be_empty
      end
    end
  end

  describe ".tools_for" do
    it "returns tools and FinalAnswerTool for a test case" do
      test_case = instance_double(
        Smolagents::Testing::TestCase,
        tools: %i[add multiply]
      )

      tools = described_class.tools_for(test_case)

      expect(tools).to be_an(Array)
      expect(tools).not_to be_empty
      expect(tools.last).to be_a(Smolagents::Tools::FinalAnswerTool)
    end

    it "includes FinalAnswerTool even for empty tool list" do
      test_case = instance_double(
        Smolagents::Testing::TestCase,
        tools: []
      )

      tools = described_class.tools_for(test_case)

      expect(tools).not_to be_empty
      expect(tools.last).to be_a(Smolagents::Tools::FinalAnswerTool)
    end

    it "maps tool names to tool instances" do
      test_case = instance_double(
        Smolagents::Testing::TestCase,
        tools: [:add]
      )

      tools = described_class.tools_for(test_case)

      add_tool = tools.find { |t| t.name == "add" }
      expect(add_tool).not_to be_nil
    end
  end

  describe ".tool_instance" do
    it "returns tool instance for known tool name" do
      tool = described_class.tool_instance(:add)

      expect(tool).to be_a(Smolagents::Tools::Tool)
      expect(tool.name).to eq("add")
    end

    it "returns tool instance for symbol" do
      tool = described_class.tool_instance(:echo)

      expect(tool).not_to be_nil
      expect(tool.name).to eq("echo")
    end

    it "returns tool instance for string" do
      tool = described_class.tool_instance("multiply")

      expect(tool).not_to be_nil
      expect(tool.name).to eq("multiply")
    end

    it "returns nil for unknown tool name" do
      # Falls back to nil when TOOL_MAP does not have the tool
      tool = described_class.tool_instance(:unknown_tool)

      expect(tool).to be_nil
    end
  end

  describe "TOOL_MAP" do
    it "contains all test tools" do
      tool_map = described_class::TOOL_MAP

      expect(tool_map).to have_key(:echo)
      expect(tool_map).to have_key(:add)
      expect(tool_map).to have_key(:multiply)
      expect(tool_map).to have_key(:get_data)
      expect(tool_map).to have_key(:failing_tool)
      expect(tool_map).to have_key(:strict_add)
    end

    it "maps symbols to Tool instances" do
      tool_map = described_class::TOOL_MAP

      tool_map.each_value do |tool|
        expect(tool).to be_a(Smolagents::Tools::Tool)
      end
    end

    it "tool map is frozen" do
      tool_map = described_class::TOOL_MAP

      expect(tool_map).to be_frozen
    end
  end

  describe "registered test cases" do
    describe "variable_persistence capability" do
      it "includes store_and_retrieve test" do
        tests = Smolagents::Testing::Capabilities.for_capability(:variable_persistence)
        names = tests.map(&:name)

        expect(names).to include("store_and_retrieve")
      end

      it "includes accumulate_state test" do
        tests = Smolagents::Testing::Capabilities.for_capability(:variable_persistence)
        names = tests.map(&:name)

        expect(names).to include("accumulate_state")
      end
    end

    describe "sequential_tools capability" do
      it "includes chain_two_tools test" do
        tests = Smolagents::Testing::Capabilities.for_capability(:sequential_tools)
        names = tests.map(&:name)

        expect(names).to include("chain_two_tools")
      end

      it "includes conditional_chain test" do
        tests = Smolagents::Testing::Capabilities.for_capability(:sequential_tools)
        names = tests.map(&:name)

        expect(names).to include("conditional_chain")
      end
    end

    describe "parallel_tools capability" do
      it "includes batch_independent_calls test" do
        tests = Smolagents::Testing::Capabilities.for_capability(:parallel_tools)
        names = tests.map(&:name)

        expect(names).to include("batch_independent_calls")
      end
    end

    describe "error_recovery capability" do
      it "includes handle_tool_error test" do
        tests = Smolagents::Testing::Capabilities.for_capability(:error_recovery)
        names = tests.map(&:name)

        expect(names).to include("handle_tool_error")
      end

      it "includes retry_with_correction test" do
        tests = Smolagents::Testing::Capabilities.for_capability(:error_recovery)
        names = tests.map(&:name)

        expect(names).to include("retry_with_correction")
      end
    end

    describe "result_synthesis capability" do
      it "includes synthesize_computation test" do
        tests = Smolagents::Testing::Capabilities.for_capability(:result_synthesis)
        names = tests.map(&:name)

        expect(names).to include("synthesize_computation")
      end
    end
  end

  describe "on_reset callback" do
    it "re-registers capabilities after reset" do
      # Reset first to get a clean baseline (removes any custom tests from other specs)
      Smolagents::Testing::Capabilities.reset!
      original_count = described_class.all_tests.length

      # Reset again and verify tests are still registered
      Smolagents::Testing::Capabilities.reset!
      new_count = described_class.all_tests.length

      expect(new_count).to eq(original_count)
    end
  end

  describe "test configuration" do
    it "sets max_steps for tests" do
      tests = described_class.all_tests

      tests.each do |test|
        expect(test.max_steps).to be_a(Integer)
        expect(test.max_steps).to be > 0
      end
    end

    it "sets timeout for tests" do
      tests = described_class.all_tests

      tests.each do |test|
        expect(test.timeout).to be_a(Integer)
        expect(test.timeout).to be > 0
      end
    end

    it "assigns tools to tests" do
      tests = described_class.all_tests

      tests.each do |test|
        expect(test.tools).to be_an(Array)
      end
    end

    it "assigns validators to tests" do
      tests = described_class.all_tests

      tests.each do |test|
        expect(test.validator).to be_a(Proc) if test.validator
      end
    end
  end

  describe "test isolation" do
    it "does not interfere with other capability registrations" do
      # Register a custom test
      Smolagents::Testing::Capabilities.register(
        :variable_persistence,
        name: "custom_test",
        task: "Custom task",
        tools: [:add],
        max_steps: 5,
        timeout: 60
      )

      # Get all tests
      all_tests = described_class.all_tests

      # Custom test should be there
      names = all_tests.map(&:name)
      expect(names).to include("custom_test")
    end
  end
end
