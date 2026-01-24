require "spec_helper"
require_relative "../../../examples/tools/01_inline_tools"

RSpec.describe "Example: Inline Tools", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  # NOTE: For simple tool use, embed the tool call in final_answer:
  #   final_answer(answer: tool_name(args))
  #
  # For multi-step scenarios with intermediate processing, each non-final
  # step needs queue_evaluation_continue after it.

  describe "create_agent_with_calculator" do
    it "registers the calculate tool" do
      model = mock_model { |m| m.queue_final_answer("42") }
      agent = create_agent_with_calculator(model)

      expect(agent.tools).to have_key("calculate")
    end

    it "executes calculations via tool call" do
      model = mock_model do |m|
        # Tool call embedded in final_answer - single step
        m.queue_code_action('final_answer(answer: calculate(expression: "6 * 7"))')
      end
      agent = create_agent_with_calculator(model)

      result = agent.run("What is 6 times 7?")

      expect(result.output).to eq(42.0)
      expect(result.state).to eq(:success)
    end

    it "computes complex expressions" do
      model = mock_model do |m|
        m.queue_code_action('final_answer(answer: calculate(expression: "(10 + 5) * 2"))')
      end
      agent = create_agent_with_calculator(model)

      result = agent.run("Add 10 and 5, then double it")

      expect(result.output).to eq(30.0)
    end
  end

  describe "create_agent_with_string_tools" do
    it "registers all three tools" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_string_tools(model)

      expect(agent.tools.keys).to include("reverse", "uppercase", "word_count")
    end

    it "can use reverse tool" do
      model = mock_model do |m|
        m.queue_code_action('final_answer(answer: reverse(text: "hello"))')
      end
      agent = create_agent_with_string_tools(model)

      result = agent.run("Reverse the word hello")

      expect(result.output).to eq("olleh")
    end

    it "can use uppercase tool" do
      model = mock_model do |m|
        m.queue_code_action('final_answer(answer: uppercase(text: "hello world"))')
      end
      agent = create_agent_with_string_tools(model)

      result = agent.run("Uppercase 'hello world'")

      expect(result.output).to eq("HELLO WORLD")
    end

    it "can use word_count tool" do
      model = mock_model do |m|
        m.queue_code_action('final_answer(answer: word_count(text: "one two three four"))')
      end
      agent = create_agent_with_string_tools(model)

      result = agent.run("Count words")

      expect(result.output).to eq(4)
    end
  end

  describe "create_agent_with_greeting" do
    it "registers greeting tool with optional parameter" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_greeting(model)

      expect(agent.tools).to have_key("greet")
    end

    it "uses default informal style" do
      model = mock_model do |m|
        m.queue_code_action('final_answer(answer: greet(name: "Alice"))')
      end
      agent = create_agent_with_greeting(model)

      result = agent.run("Greet Alice")

      expect(result.output).to eq("Hey Alice!")
    end

    it "uses formal style when specified" do
      model = mock_model do |m|
        m.queue_code_action('final_answer(answer: greet(name: "Bob", formal: true))')
      end
      agent = create_agent_with_greeting(model)

      result = agent.run("Greet Bob formally")

      expect(result.output).to eq("Good day, Bob.")
    end
  end

  describe "create_agent_with_data_tool" do
    it "registers analyze tool" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_data_tool(model)

      expect(agent.tools).to have_key("analyze")
    end

    it "returns structured analysis" do
      model = mock_model do |m|
        m.queue_code_action('final_answer(answer: analyze(text: "Hello. World."))')
      end
      agent = create_agent_with_data_tool(model)

      result = agent.run("Analyze the text")

      expect(result.output).to be_a(Hash)
      expect(result.output[:words]).to eq(2)
      expect(result.output[:sentences]).to eq(2)
    end
  end

  describe "create_agent_with_mixed_tools" do
    it "has inline summarize tool" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_mixed_tools(model)

      expect(agent.tools.keys).to include("summarize")
    end

    it "can use inline tool" do
      model = mock_model do |m|
        m.queue_code_action(
          'final_answer(answer: summarize(text: "This is a very long piece of text."))'
        )
      end
      agent = create_agent_with_mixed_tools(model)

      result = agent.run("Summarize the text")

      expect(result.output).to start_with("This is a very")
      expect(result.output).to end_with("...")
    end
  end

  describe "tool DSL syntax" do
    it "accepts symbol name" do
      model = mock_model { |m| m.queue_final_answer("ok") }

      agent = Smolagents.agent
                        .model { model }
                        .tool(:my_tool, "A tool", input: String) { |input:| input }
                        .build

      expect(agent.tools).to have_key("my_tool")
    end

    it "accepts string name" do
      model = mock_model { |m| m.queue_final_answer("ok") }

      agent = Smolagents.agent
                        .model { model }
                        .tool("my_tool", "A tool", input: String) { |input:| input }
                        .build

      expect(agent.tools).to have_key("my_tool")
    end

    it "tool description appears in system prompt" do
      model = mock_model { |m| m.queue_final_answer("ok") }

      agent = Smolagents.agent
                        .model { model }
                        .tool(:special, "This does something special", x: Integer) { |x:| x * 2 }
                        .build

      agent.run("test")

      system_msg = model.calls.first.messages.find { |m| m.role == :system }
      expect(system_msg.content).to include("something special")
    end

    it "tool can transform input and return result" do
      model = mock_model do |m|
        m.queue_code_action("final_answer(answer: double(x: 21))")
      end

      agent = Smolagents.agent
                        .model { model }
                        .tool(:double, "Double a number", x: Integer) { |x:| x * 2 }
                        .build

      result = agent.run("Double 21")

      expect(result.output).to eq(42)
    end
  end
end
