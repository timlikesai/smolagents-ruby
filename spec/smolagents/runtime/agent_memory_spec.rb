require "spec_helper"

RSpec.describe Smolagents::Runtime::AgentMemory do
  subject(:memory) { described_class.new(system_prompt, config:) }

  let(:system_prompt) { "You are a helpful assistant." }
  let(:config) { Smolagents::Types::MemoryConfig.default }

  describe "#initialize" do
    it "creates memory with system prompt" do
      expect(memory.system_prompt).to be_a(Smolagents::Types::SystemPromptStep)
      expect(memory.system_prompt.system_prompt).to eq(system_prompt)
    end

    it "starts with empty steps" do
      expect(memory.steps).to be_empty
    end

    it "stores the config" do
      expect(memory.config).to eq(config)
    end
  end

  describe "#reset" do
    before do
      memory.add_task("Test task")
    end

    it "clears all steps" do
      memory.reset

      expect(memory.steps).to be_empty
    end

    it "preserves system prompt" do
      memory.reset

      expect(memory.system_prompt.system_prompt).to eq(system_prompt)
    end
  end

  describe "#add_task" do
    it "adds a task step" do
      memory.add_task("Calculate 2+2")

      expect(memory.steps.size).to eq(1)
      expect(memory.steps.first).to be_a(Smolagents::Types::TaskStep)
      expect(memory.steps.first.task).to eq("Calculate 2+2")
    end

    it "appends additional prompting" do
      memory.add_task("Calculate", additional_prompting: "Show your work")

      expect(memory.steps.first.task).to eq("Calculate\n\nShow your work")
    end

    it "stores task images" do
      memory.add_task("Describe image", task_images: ["/path/to/img.png"])

      expect(memory.steps.first.task_images).to eq(["/path/to/img.png"])
    end

    it "handles nil additional_prompting" do
      memory.add_task("Simple task", additional_prompting: nil)

      expect(memory.steps.first.task).to eq("Simple task")
    end
  end

  describe "#add_step / #<<" do
    let(:action_step) do
      Smolagents::Types::ActionStep.new(
        step_number: 0,
        observations: "Result: 4"
      )
    end

    it "adds step with add_step" do
      memory.add_step(action_step)

      expect(memory.steps).to contain_exactly(action_step)
    end

    it "adds step with << operator" do
      memory << action_step

      expect(memory.steps).to contain_exactly(action_step)
    end
  end

  describe "#to_messages" do
    before do
      memory.add_task("Calculate 2+2")
    end

    it "includes system prompt message" do
      messages = memory.to_messages

      expect(messages.first.role).to eq(:system)
      expect(messages.first.content).to eq(system_prompt)
    end

    it "includes task message" do
      messages = memory.to_messages

      expect(messages.last.role).to eq(:user)
      expect(messages.last.content).to eq("Calculate 2+2")
    end

    it "passes summary_mode to step conversion" do
      memory << Smolagents::Types::ActionStep.new(
        step_number: 0,
        model_output_message: Smolagents::Types::ChatMessage.assistant("Let me calculate"),
        observations: "4"
      )

      summary_messages = memory.to_messages(summary_mode: true)
      full_messages = memory.to_messages(summary_mode: false)

      # Summary mode excludes model output message
      expect(summary_messages.size).to be < full_messages.size
    end
  end

  describe "#stats" do
    before do
      memory.add_task("Test task")
      memory << Smolagents::Types::ActionStep.new(step_number: 0, observations: "Done")
      memory << Smolagents::Types::PlanningStep.new(
        model_input_messages: [],
        model_output_message: nil,
        plan: "1. Do X\n2. Do Y",
        timing: nil,
        token_usage: nil
      )
    end

    it "includes step counts" do
      stats = memory.stats

      expect(stats[:step_count]).to eq(3)
      expect(stats[:action_step_count]).to eq(1)
      expect(stats[:task_step_count]).to eq(1)
      expect(stats[:planning_step_count]).to eq(1)
    end

    it "includes budget stats" do
      stats = memory.stats

      expect(stats).to have_key(:estimated_tokens)
      expect(stats).to have_key(:budget)
      expect(stats).to have_key(:over_budget)
      expect(stats).to have_key(:headroom)
      expect(stats).to have_key(:strategy)
    end
  end

  describe "#succinct_steps" do
    before do
      memory.add_task("Test task")
      memory << Smolagents::Types::ActionStep.new(step_number: 0, observations: "Result")
    end

    it "returns steps as hashes" do
      succinct = memory.succinct_steps

      expect(succinct).to all(be_a(Hash))
      expect(succinct.size).to eq(2)
    end
  end

  describe "#full_steps" do
    before do
      memory.add_task("Test task")
    end

    it "returns steps with full marker" do
      full = memory.full_steps

      expect(full.first).to include(full: true)
    end
  end

  describe "#return_full_code" do
    it "returns empty string when no action steps" do
      memory.add_task("Test")

      expect(memory.return_full_code).to eq("")
    end

    it "concatenates code from action steps" do
      memory << Smolagents::Types::ActionStep.new(step_number: 0, code_action: "x = 1")
      memory << Smolagents::Types::ActionStep.new(step_number: 1, code_action: "y = 2")

      code = memory.return_full_code

      expect(code).to eq("x = 1\n\ny = 2")
    end

    it "skips steps without code_action" do
      memory << Smolagents::Types::ActionStep.new(step_number: 0, code_action: "x = 1")
      memory << Smolagents::Types::ActionStep.new(step_number: 1, code_action: nil)
      memory << Smolagents::Types::ActionStep.new(step_number: 2, code_action: "z = 3")

      code = memory.return_full_code

      expect(code).to eq("x = 1\n\nz = 3")
    end
  end

  describe "step filtering" do
    before do
      memory.add_task("Task 1")
      memory << Smolagents::Types::ActionStep.new(step_number: 0, observations: "Action 1")
      memory << Smolagents::Types::PlanningStep.new(
        model_input_messages: [],
        model_output_message: nil,
        plan: "Plan 1",
        timing: nil,
        token_usage: nil
      )
      memory.add_task("Task 2")
      memory << Smolagents::Types::ActionStep.new(step_number: 1, observations: "Action 2")
    end

    it "filters action_steps" do
      action_steps = memory.action_steps.to_a

      expect(action_steps.size).to eq(2)
      expect(action_steps).to all(be_a(Smolagents::Types::ActionStep))
    end

    it "filters task_steps" do
      task_steps = memory.task_steps.to_a

      expect(task_steps.size).to eq(2)
      expect(task_steps).to all(be_a(Smolagents::Types::TaskStep))
    end

    it "filters planning_steps" do
      planning_steps = memory.planning_steps.to_a

      expect(planning_steps.size).to eq(1)
      expect(planning_steps.first).to be_a(Smolagents::Types::PlanningStep)
    end

    it "returns lazy enumerators" do
      expect(memory.action_steps).to be_a(Enumerator::Lazy)
      expect(memory.task_steps).to be_a(Enumerator::Lazy)
      expect(memory.planning_steps).to be_a(Enumerator::Lazy)
    end
  end
end
