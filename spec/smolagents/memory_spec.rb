# frozen_string_literal: true

RSpec.describe Smolagents::AgentMemory do
  let(:system_prompt) { "You are a helpful assistant" }
  subject(:memory) { described_class.new(system_prompt) }

  describe "#initialize" do
    it "stores system prompt as SystemPromptStep" do
      expect(memory.system_prompt).to be_a(Smolagents::SystemPromptStep)
      expect(memory.system_prompt.system_prompt).to eq(system_prompt)
    end

    it "initializes with empty steps" do
      expect(memory.steps).to be_empty
    end
  end

  describe "#reset" do
    it "clears all steps" do
      memory << Smolagents::TaskStep.new(task: "Test task")
      memory << Smolagents::ActionStep.new(step_number: 1)

      memory.reset

      expect(memory.steps).to be_empty
    end

    it "keeps system prompt" do
      memory.reset
      expect(memory.system_prompt).to be_a(Smolagents::SystemPromptStep)
    end
  end

  describe "#add_step / #<<" do
    it "adds step to memory" do
      step = Smolagents::TaskStep.new(task: "Test")
      memory << step
      expect(memory.steps).to include(step)
    end
  end

  describe "#to_messages" do
    it "includes system prompt message" do
      messages = memory.to_messages
      expect(messages.first.role).to eq(:system)
      expect(messages.first.content).to eq(system_prompt)
    end

    it "includes task step messages" do
      task_step = Smolagents::TaskStep.new(task: "Do something")
      memory << task_step

      messages = memory.to_messages
      expect(messages.last.role).to eq(:user)
      expect(messages.last.content).to eq("Do something")
    end
  end

  describe "#return_full_code" do
    it "concatenates code from ActionSteps" do
      action1 = Smolagents::ActionStep.new(step_number: 1)
      action1.code_action = "x = 1 + 1"

      action2 = Smolagents::ActionStep.new(step_number: 2)
      action2.code_action = "puts x"

      memory << action1
      memory << action2

      expect(memory.return_full_code).to eq("x = 1 + 1\n\nputs x")
    end

    it "skips ActionSteps without code" do
      action1 = Smolagents::ActionStep.new(step_number: 1)
      action1.code_action = nil

      action2 = Smolagents::ActionStep.new(step_number: 2)
      action2.code_action = "puts 'hello'"

      memory << action1
      memory << action2

      expect(memory.return_full_code).to eq("puts 'hello'")
    end
  end

  describe "#get_succinct_steps" do
    it "returns array of step hashes" do
      memory << Smolagents::TaskStep.new(task: "Test")
      steps = memory.get_succinct_steps
      expect(steps).to be_an(Array)
      expect(steps.first).to be_a(Hash)
      expect(steps.first[:task]).to eq("Test")
    end
  end
end

RSpec.describe Smolagents::ActionStep do
  describe "#initialize" do
    it "sets step number and timing" do
      step = described_class.new(step_number: 1)
      expect(step.step_number).to eq(1)
      expect(step.timing).to be_a(Smolagents::Timing)
    end

    it "defaults is_final_answer to false" do
      step = described_class.new(step_number: 1)
      expect(step.is_final_answer).to be false
    end
  end

  describe "#to_h" do
    it "includes step data" do
      step = described_class.new(step_number: 1)
      step.code_action = "x = 1"
      step.observations = "Output: 1"

      hash = step.to_h
      expect(hash[:step_number]).to eq(1)
      expect(hash[:code_action]).to eq("x = 1")
      expect(hash[:observations]).to eq("Output: 1")
    end
  end
end

RSpec.describe Smolagents::TaskStep do
  describe "#to_h" do
    it "includes task" do
      step = described_class.new(task: "Solve problem")
      expect(step.to_h[:task]).to eq("Solve problem")
    end
  end

  describe "#to_messages" do
    it "returns user message with task" do
      step = described_class.new(task: "Test task")
      messages = step.to_messages
      expect(messages.length).to eq(1)
      expect(messages.first.role).to eq(:user)
      expect(messages.first.content).to eq("Test task")
    end
  end
end

RSpec.describe Smolagents::SystemPromptStep do
  describe "#to_messages" do
    it "returns system message" do
      step = described_class.new(system_prompt: "You are helpful")
      messages = step.to_messages
      expect(messages.length).to eq(1)
      expect(messages.first.role).to eq(:system)
    end
  end
end

RSpec.describe Smolagents::FinalAnswerStep do
  describe "#to_h" do
    it "includes output" do
      step = described_class.new(output: "42")
      expect(step.to_h[:output]).to eq("42")
    end
  end

  describe "#to_messages" do
    it "returns empty array" do
      step = described_class.new(output: "done")
      expect(step.to_messages).to eq([])
    end
  end
end
