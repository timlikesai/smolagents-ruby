RSpec.describe Smolagents::AgentMemory do
  subject(:memory) { described_class.new(system_prompt) }

  let(:system_prompt) { "You are a helpful assistant" }

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
      memory << Smolagents::ActionStep.new(
        step_number: 1,
        timing: Smolagents::Timing.start_now,
        is_final_answer: false
      )

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
      action1 = Smolagents::ActionStep.new(
        step_number: 1,
        timing: Smolagents::Timing.start_now,
        code_action: "x = 1 + 1",
        is_final_answer: false
      )

      action2 = Smolagents::ActionStep.new(
        step_number: 2,
        timing: Smolagents::Timing.start_now,
        code_action: "puts x",
        is_final_answer: false
      )

      memory << action1
      memory << action2

      expect(memory.return_full_code).to eq("x = 1 + 1\n\nputs x")
    end

    it "skips ActionSteps without code" do
      action1 = Smolagents::ActionStep.new(
        step_number: 1,
        timing: Smolagents::Timing.start_now,
        code_action: nil,
        is_final_answer: false
      )

      action2 = Smolagents::ActionStep.new(
        step_number: 2,
        timing: Smolagents::Timing.start_now,
        code_action: "puts 'hello'",
        is_final_answer: false
      )

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

  describe "#action_steps" do
    it "returns a lazy enumerator" do
      expect(memory.action_steps).to be_a(Enumerator::Lazy)
    end

    it "filters only ActionStep instances" do
      memory << Smolagents::TaskStep.new(task: "Test task")
      memory << Smolagents::ActionStep.new(step_number: 1, observations: "First")
      memory << Smolagents::PlanningStep.new(plan: "Plan", model_input_messages: [], model_output_message: nil, timing: nil, token_usage: nil)
      memory << Smolagents::ActionStep.new(step_number: 2, observations: "Second")

      action_steps = memory.action_steps.to_a
      expect(action_steps.length).to eq(2)
      expect(action_steps.all?(Smolagents::ActionStep)).to be true
    end

    it "processes lazily" do
      processed = []
      memory.instance_variable_set(:@steps, Enumerator.new do |y|
        3.times do |i|
          processed << i
          y << Smolagents::ActionStep.new(step_number: i + 1, observations: "Obs #{i}")
        end
      end.to_a)

      lazy_steps = memory.action_steps
      expect(lazy_steps).to be_a(Enumerator::Lazy)
    end
  end

  describe "#planning_steps" do
    it "returns a lazy enumerator" do
      expect(memory.planning_steps).to be_a(Enumerator::Lazy)
    end

    it "filters only PlanningStep instances" do
      memory << Smolagents::TaskStep.new(task: "Test task")
      memory << Smolagents::PlanningStep.new(plan: "Plan 1", model_input_messages: [], model_output_message: nil, timing: nil, token_usage: nil)
      memory << Smolagents::ActionStep.new(step_number: 1, observations: "Action")
      memory << Smolagents::PlanningStep.new(plan: "Plan 2", model_input_messages: [], model_output_message: nil, timing: nil, token_usage: nil)

      planning_steps = memory.planning_steps.to_a
      expect(planning_steps.length).to eq(2)
      expect(planning_steps.all?(Smolagents::PlanningStep)).to be true
    end
  end

  describe "#task_steps" do
    it "returns a lazy enumerator" do
      expect(memory.task_steps).to be_a(Enumerator::Lazy)
    end

    it "filters only TaskStep instances" do
      memory << Smolagents::TaskStep.new(task: "Task 1")
      memory << Smolagents::ActionStep.new(step_number: 1, observations: "Action")
      memory << Smolagents::TaskStep.new(task: "Task 2")

      task_steps = memory.task_steps.to_a
      expect(task_steps.length).to eq(2)
      expect(task_steps.all?(Smolagents::TaskStep)).to be true
    end
  end
end

RSpec.describe Smolagents::ActionStep do
  describe "#new" do
    it "sets step number and timing" do
      timing = Smolagents::Timing.start_now
      step = described_class.new(
        step_number: 1,
        timing: timing,
        is_final_answer: false
      )
      expect(step.step_number).to eq(1)
      expect(step.timing).to be_a(Smolagents::Timing)
    end

    it "defaults is_final_answer to false" do
      step = described_class.new(
        step_number: 1,
        timing: Smolagents::Timing.start_now,
        is_final_answer: false
      )
      expect(step.is_final_answer).to be false
    end
  end

  describe "#to_h" do
    it "includes step data" do
      step = described_class.new(
        step_number: 1,
        timing: Smolagents::Timing.start_now,
        code_action: "x = 1",
        observations: "Output: 1",
        is_final_answer: false
      )

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
