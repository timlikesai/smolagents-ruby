RSpec.describe "AgentRuntime::StepExecution mode branching" do
  let(:runtime_class) do
    Class.new do
      include Smolagents::Concerns::StepExecution
      include Smolagents::Agents::AgentRuntime::StepExecution

      attr_accessor :model, :logger

      def execute_step(action_step) = action_step.observations = "code_mode"

      def execute_native_step(action_step) = action_step.observations = "native_mode"
    end
  end

  let(:instance) { runtime_class.new }
  let(:logger) { double("Logger", step_start: nil, step_complete: nil, error: nil) }

  before { instance.logger = logger }

  context "when model uses code mode" do
    before do
      model = double("Model", tool_calling_mode: :code)
      instance.model = model
    end

    it "calls execute_step" do
      step = instance.step("task", step_number: 0)
      expect(step.observations).to eq("code_mode")
    end
  end

  context "when model uses native mode" do
    before do
      model = double("Model", tool_calling_mode: :native)
      instance.model = model
    end

    it "calls execute_native_step" do
      step = instance.step("task", step_number: 0)
      expect(step.observations).to eq("native_mode")
    end
  end

  context "when model doesn't respond to tool_calling_mode" do
    before do
      model = double("Model")
      instance.model = model
    end

    it "falls back to code mode" do
      step = instance.step("task", step_number: 0)
      expect(step.observations).to eq("code_mode")
    end
  end
end
