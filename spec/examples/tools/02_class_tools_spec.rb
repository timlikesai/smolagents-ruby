require "spec_helper"
require_relative "../../../examples/tools/02_class_tools"

RSpec.describe "Example: Class-Based Tools", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe TemperatureConverter do
    let(:tool) { described_class.new }

    it "has correct metadata" do
      expect(tool.tool_name).to eq("convert_temp")
      expect(tool.description).to include("temperature")
    end

    it "converts Celsius to Fahrenheit" do
      result = tool.call(value: 100, from_unit: "C")

      expect(result.data[:value]).to eq(212.0)
      expect(result.data[:unit]).to eq("F")
    end

    it "converts Fahrenheit to Celsius" do
      result = tool.call(value: 32, from_unit: "F")

      expect(result.data[:value]).to eq(0.0)
      expect(result.data[:unit]).to eq("C")
    end

    it "handles lowercase units" do
      result = tool.call(value: 0, from_unit: "c")

      expect(result.data[:value]).to eq(32.0)
    end

    it "raises on unknown unit" do
      expect { tool.call(value: 100, from_unit: "K") }
        .to raise_error(ArgumentError, /Unknown unit/)
    end
  end

  describe CounterTool do
    let(:tool) { described_class.new }

    it "has correct metadata" do
      expect(tool.tool_name).to eq("counter")
    end

    it "starts at zero and increments" do
      expect(tool.call.data).to eq(1)
      expect(tool.call.data).to eq(2)
      expect(tool.call.data).to eq(3)
    end

    it "maintains separate state per instance" do
      tool1 = described_class.new
      tool2 = described_class.new

      tool1.call
      tool1.call

      expect(tool1.call.data).to eq(3)
      expect(tool2.call.data).to eq(1)
    end
  end

  describe SearchTool do
    it "uses default max_results" do
      tool = described_class.new
      result = tool.call(query: "ruby")

      expect(result.data.size).to eq(5)
    end

    it "accepts custom max_results" do
      tool = described_class.new(max_results: 3)
      result = tool.call(query: "ruby")

      expect(result.data.size).to eq(3)
    end

    it "includes query in results" do
      tool = described_class.new(max_results: 1)
      result = tool.call(query: "test query")

      expect(result.data.first).to include("test query")
    end
  end

  describe AnalysisTool do
    let(:tool) { described_class.new }

    it "has output schema defined" do
      expect(tool.class.output_schema).to have_key(:word_count)
      expect(tool.class.output_schema).to have_key(:char_count)
      expect(tool.class.output_schema).to have_key(:sentence_count)
    end

    it "analyzes text correctly" do
      result = tool.call(text: "Hello world. This is a test!")

      expect(result.data[:word_count]).to eq(6)
      expect(result.data[:char_count]).to eq(28)
      expect(result.data[:sentence_count]).to eq(2)
    end

    it "handles empty text" do
      result = tool.call(text: "")

      expect(result.data[:word_count]).to eq(0)
      expect(result.data[:char_count]).to eq(0)
    end
  end

  describe "create_agent_with_class_tools" do
    it "registers all tools" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_class_tools(model)

      expect(agent.tools.keys).to include("convert_temp", "counter", "search")
    end

    it "tools work through agent", max_time: 0.15 do
      model = mock_model do |m|
        m.queue_code_action('final_answer(answer: convert_temp(value: 100, from_unit: "C"))')
      end
      agent = create_agent_with_class_tools(model)

      result = agent.run("Convert 100C to Fahrenheit")

      # Tool results have string keys for LLM compatibility
      expect(result.output["value"]).to eq(212.0)
      expect(result.output["unit"]).to eq("F")
    end

    it "search respects configured max_results" do
      model = mock_model do |m|
        m.queue_code_action('final_answer(answer: search(query: "ruby"))')
      end
      agent = create_agent_with_class_tools(model)

      result = agent.run("Search for ruby")

      expect(result.output.size).to eq(3) # configured to 3 in example
    end
  end

  describe "tool lifecycle" do
    it "setup is called automatically on first use" do
      tool = CounterTool.new
      expect(tool.initialized?).to be false

      tool.call
      expect(tool.initialized?).to be true
    end

    it "setup is only called once" do
      tool = CounterTool.new

      3.times { tool.call }

      # Counter would be different if setup was called multiple times
      expect(tool.call.data).to eq(4)
    end
  end

  describe "ToolResult wrapping" do
    it "call returns ToolResult" do
      tool = TemperatureConverter.new
      result = tool.call(value: 0, from_unit: "C")

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.tool_name).to eq("convert_temp")
    end

    it "ToolResult provides data access" do
      tool = AnalysisTool.new
      result = tool.call(text: "Hello world")

      expect(result.data).to be_a(Hash)
      expect(result[:word_count]).to eq(2)
    end
  end

  # ============================================================================
  # Event Integration
  # ============================================================================
  # Demonstrates how to monitor class-based tool execution via event subscriptions.
  # Events capture tool_name, result, and observation for observability.
  #
  # Key events for tool monitoring:
  # - :tool_complete (ToolCallCompleted) - fired after each tool execution
  # - :step_complete (StepCompleted) - fired after each agent step
  #
  # Use .sync_events to ensure handlers fire during execution (needed for testing).

  describe "event integration" do
    include Smolagents::Testing::Helpers::ModelHelpers

    describe "tracking class tool results with :tool_complete" do
      it "captures structured results and observation" do
        results = []

        model = mock_model do |m|
          m.queue_code_action('final_answer(answer: analyze_text(text: "Hello world!"))')
        end

        agent = Smolagents.agent
                          .model { model }
                          .tools(AnalysisTool.new)
                          .sync_events
                          .on(:tool_complete) do |e|
                            results << {
                              tool: e.tool_name,
                              result: e.result,
                              observation: e.observation
                            }
                          end
                          .build

        agent.run("Analyze the text")

        analyze_result = results.find { |r| r[:tool] == "analyze_text" }
        expect(analyze_result[:result]).to be_a(Hash)
        # Tool results have string keys for LLM compatibility
        expect(analyze_result[:result]["word_count"]).to eq(2)
        # Observation is the string representation shown to the model
        expect(analyze_result[:observation]).to be_a(String)
      end

      it "captures temperature conversion results" do
        conversions = []

        model = mock_model do |m|
          m.queue_code_action('final_answer(answer: convert_temp(value: 100, from_unit: "C"))')
        end

        agent = Smolagents.agent
                          .model { model }
                          .tools(TemperatureConverter.new)
                          .sync_events
                          .on(:tool_complete) do |e|
                            conversions << { tool: e.tool_name, result: e.result }
                          end
                          .build

        agent.run("Convert 100C to Fahrenheit")

        temp_event = conversions.find { |c| c[:tool] == "convert_temp" }
        expect(temp_event[:result]).to be_a(Hash)
        # Tool results have string keys for LLM compatibility
        expect(temp_event[:result]["value"]).to eq(212.0)
        expect(temp_event[:result]["unit"]).to eq("F")
      end
    end

    describe "monitoring stateful tools" do
      it "tracks state changes across multiple calls" do
        counter_values = []

        model = mock_model do |m|
          # First call increments to 1
          m.queue_code_action("counter()")
          m.queue_evaluation_continue
          # Second call increments to 2, then return via final_answer
          m.queue_code_action("final_answer(answer: counter())")
        end

        agent = Smolagents.agent
                          .model { model }
                          .tools(CounterTool.new)
                          .sync_events
                          .on(:tool_complete) do |e|
                            counter_values << e.result if e.tool_name == "counter"
                          end
                          .build

        result = agent.run("Increment counter twice")

        expect(counter_values).to eq([1, 2])
        expect(result.output).to eq(2)
      end
    end

    describe "building observability with combined events" do
      it "creates a full execution log" do
        log = []

        model = mock_model do |m|
          m.queue_code_action('final_answer(answer: search(query: "ruby gems"))')
        end

        agent = Smolagents.agent
                          .model { model }
                          .tools(SearchTool.new(max_results: 2))
                          .sync_events
                          .on(:tool_complete) do |e|
                            preview = e.result.is_a?(Array) ? "#{e.result.size} results" : e.result.to_s[0..20]
                            log << "DONE: #{e.tool_name} => #{preview}"
                          end
                          .on(:step_complete) do |e|
                            log << "STEP: #{e.step_number} (#{e.outcome})"
                          end
                          .build

        agent.run("Search for ruby gems")

        # Verify the log captures the execution flow
        expect(log.any? { |l| l.include?("DONE: search => 2 results") }).to be true
        expect(log.any? { |l| l.include?("STEP:") }).to be true
      end
    end

    describe "convenience handler on_tool" do
      it "is equivalent to on(:tool_complete)" do
        tool_names = []

        model = mock_model do |m|
          m.queue_code_action("final_answer(answer: counter())")
        end

        # on_tool is a convenience for on(:tool_complete)
        agent = Smolagents.agent
                          .model { model }
                          .tools(CounterTool.new)
                          .sync_events
                          .on_tool { |e| tool_names << e.tool_name }
                          .build

        agent.run("Increment counter")

        expect(tool_names).to include("counter")
        expect(tool_names).to include("final_answer")
      end
    end
  end
end
