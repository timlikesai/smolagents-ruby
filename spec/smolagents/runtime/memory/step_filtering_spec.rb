require "spec_helper"

RSpec.describe Smolagents::Runtime::Memory::StepFiltering do
  subject(:memory) { memory_class.new }

  let(:memory_class) do
    Class.new do
      include Smolagents::Runtime::Memory::StepFiltering

      attr_reader :steps

      def initialize
        @steps = []
      end

      def <<(step) = @steps << step
    end
  end

  describe ".included" do
    it "defines step filter methods on the including class" do
      expect(memory).to respond_to(:action_steps)
      expect(memory).to respond_to(:planning_steps)
      expect(memory).to respond_to(:task_steps)
    end
  end

  describe "#action_steps" do
    it "returns lazy enumerator" do
      expect(memory.action_steps).to be_a(Enumerator::Lazy)
    end

    it "filters only ActionStep instances" do
      memory << Smolagents::Types::TaskStep.new(task: "Task 1")
      memory << Smolagents::Types::ActionStep.new(step_number: 0, observations: "Obs 1")
      memory << Smolagents::Types::PlanningStep.new(
        model_input_messages: [],
        model_output_message: nil,
        plan: "Plan",
        timing: nil,
        token_usage: nil
      )
      memory << Smolagents::Types::ActionStep.new(step_number: 1, observations: "Obs 2")

      action_steps = memory.action_steps.to_a

      expect(action_steps.size).to eq(2)
      expect(action_steps).to all(be_a(Smolagents::Types::ActionStep))
      expect(action_steps.map(&:step_number)).to eq([0, 1])
    end

    it "returns empty enumerator when no action steps" do
      memory << Smolagents::Types::TaskStep.new(task: "Task only")

      expect(memory.action_steps.to_a).to be_empty
    end
  end

  describe "#planning_steps" do
    it "returns lazy enumerator" do
      expect(memory.planning_steps).to be_a(Enumerator::Lazy)
    end

    it "filters only PlanningStep instances" do
      memory << Smolagents::Types::TaskStep.new(task: "Task")
      memory << Smolagents::Types::PlanningStep.new(
        model_input_messages: [],
        model_output_message: nil,
        plan: "Plan 1",
        timing: nil,
        token_usage: nil
      )
      memory << Smolagents::Types::ActionStep.new(step_number: 0, observations: "Action")
      memory << Smolagents::Types::PlanningStep.new(
        model_input_messages: [],
        model_output_message: nil,
        plan: "Plan 2",
        timing: nil,
        token_usage: nil
      )

      planning_steps = memory.planning_steps.to_a

      expect(planning_steps.size).to eq(2)
      expect(planning_steps).to all(be_a(Smolagents::Types::PlanningStep))
      expect(planning_steps.map(&:plan)).to eq(["Plan 1", "Plan 2"])
    end

    it "returns empty enumerator when no planning steps" do
      memory << Smolagents::Types::ActionStep.new(step_number: 0, observations: "Action only")

      expect(memory.planning_steps.to_a).to be_empty
    end
  end

  describe "#task_steps" do
    it "returns lazy enumerator" do
      expect(memory.task_steps).to be_a(Enumerator::Lazy)
    end

    it "filters only TaskStep instances" do
      memory << Smolagents::Types::TaskStep.new(task: "Task 1")
      memory << Smolagents::Types::ActionStep.new(step_number: 0, observations: "Action")
      memory << Smolagents::Types::TaskStep.new(task: "Task 2")
      memory << Smolagents::Types::TaskStep.new(task: "Task 3")

      task_steps = memory.task_steps.to_a

      expect(task_steps.size).to eq(3)
      expect(task_steps).to all(be_a(Smolagents::Types::TaskStep))
      expect(task_steps.map(&:task)).to eq(["Task 1", "Task 2", "Task 3"])
    end

    it "returns empty enumerator when no task steps" do
      memory << Smolagents::Types::ActionStep.new(step_number: 0, observations: "Action only")

      expect(memory.task_steps.to_a).to be_empty
    end
  end

  describe "lazy evaluation" do
    it "does not iterate until forced" do
      iteration_count = 0
      steps = (1..100).map do |i|
        iteration_count += 1
        Smolagents::Types::ActionStep.new(step_number: i, observations: "Obs #{i}")
      end
      steps.each { |s| memory << s }
      iteration_count = 0

      # Get first 2 action steps lazily
      memory.action_steps.take(2).each { iteration_count += 1 }

      expect(iteration_count).to eq(2)
    end

    it "supports chaining lazy operations" do
      5.times { |i| memory << Smolagents::Types::ActionStep.new(step_number: i, observations: "Obs #{i}") }

      result = memory.action_steps
                     .select { |s| s.step_number > 1 }
                     .take(2)
                     .to_a

      expect(result.map(&:step_number)).to eq([2, 3])
    end
  end
end
