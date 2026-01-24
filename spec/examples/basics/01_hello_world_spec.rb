require "spec_helper"
require_relative "../../../examples_new/basics/01_hello_world"

RSpec.describe "Example: Hello World", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "create_minimal_agent" do
    it "creates an agent with just a model" do
      model = mock_model { |m| m.queue_final_answer("Paris") }
      agent = create_minimal_agent(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
      # NOTE: final_answer is always present - it's how agents signal completion
      expect(agent.tools.keys).to eq(["final_answer"])
    end

    it "runs and returns a final answer" do
      model = mock_model { |m| m.queue_final_answer("Paris") }
      agent = create_minimal_agent(model)

      result = agent.run("What is the capital of France?")

      expect(result.output).to eq("Paris")
      expect(result.state).to eq(:success)
      expect(model).to be_exhausted
    end

    it "passes the task to the model" do
      model = mock_model { |m| m.queue_final_answer("42") }
      agent = create_minimal_agent(model)

      agent.run("What is the meaning of life?")

      expect(model.calls.first.messages).to include(
        satisfy { |m| m.content.include?("What is the meaning of life?") }
      )
    end
  end

  describe "create_agent_with_instructions" do
    it "includes custom instructions in system prompt" do
      model = mock_model { |m| m.queue_final_answer("Code flows free\nRuby gems sparkle\nAgents think") }
      agent = create_agent_with_instructions(model)

      agent.run("Write a haiku about programming")

      system_message = model.calls.first.messages.find { |m| m.role == :system }
      expect(system_message.content).to include("haiku")
    end

    it "agent follows instructions in response" do
      model = mock_model do |m|
        m.queue_final_answer("Morning dew glistens\nSunlight breaks through clouded sky\nNature awakens")
      end
      agent = create_agent_with_instructions(model)

      result = agent.run("Write a haiku about morning")

      expect(result.output).to include("Morning")
    end
  end

  describe "create_agent_with_persona" do
    it "applies persona instructions" do
      model = mock_model { |m| m.queue_final_answer("Based on my research...") }
      agent = create_agent_with_persona(model)

      agent.run("Research quantum computing")

      system_message = model.calls.first.messages.find { |m| m.role == :system }
      # Persona adds research-focused instructions
      expect(system_message.content).to match(/research|thorough|sources/i)
    end
  end

  describe "DSL fluency" do
    it "supports method chaining" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .instructions("Be concise.")
                        .instructions("Be accurate.")
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "model block is lazily evaluated" do
      call_count = 0
      builder = Smolagents.agent.model do
        call_count += 1
        mock_model { |m| m.queue_final_answer("ok") }
      end

      expect(call_count).to eq(0)
      builder.build
      expect(call_count).to eq(1)
    end
  end
end
