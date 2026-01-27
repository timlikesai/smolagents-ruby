require "smolagents/concerns/execution/budget_tracking"

RSpec.describe Smolagents::Concerns::BudgetTracking do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::BudgetTracking

      attr_accessor :max_steps, :memory
    end
  end

  let(:instance) { test_class.new }

  let(:mock_action_step) do
    instance_double(Smolagents::Types::ActionStep,
                    step_number: 5)
  end

  before do
    instance.max_steps = 10
  end

  describe "#with_budget_reminder" do
    it "returns logs unchanged when no max_steps set" do
      instance.max_steps = nil
      logs = "Some output"

      result = instance.send(:with_budget_reminder, mock_action_step, logs)
      expect(result).to eq(logs)
    end

    context "with budget remaining" do
      it "returns unchanged logs when plenty of steps remain" do
        action_step = instance_double(Smolagents::Types::ActionStep, step_number: 2)
        instance.max_steps = 10
        logs = "Standard output"

        result = instance.send(:with_budget_reminder, action_step, logs)
        expect(result).to eq(logs)
      end

      it "adds budget reminder when 2 steps remain" do
        # remaining = max_steps - step_number - 1 = 10 - 7 - 1 = 2
        action_step = instance_double(Smolagents::Types::ActionStep, step_number: 7)
        instance.max_steps = 10
        logs = "Output"

        result = instance.send(:with_budget_reminder, action_step, logs)
        expect(result).to include("[Budget:")
        expect(result).to include("2 steps remaining")
      end

      it "uses singular 'step' when 1 step remains" do
        # remaining = max_steps - step_number - 1 = 10 - 8 - 1 = 1
        action_step = instance_double(Smolagents::Types::ActionStep, step_number: 8)
        instance.max_steps = 10
        logs = "Output"

        result = instance.send(:with_budget_reminder, action_step, logs)
        expect(result).to include("1 step remaining")
      end

      it "adds budget reminder with plural when exactly 2 remain" do
        # remaining = max_steps - step_number - 1 = 10 - 7 - 1 = 2
        action_step = instance_double(Smolagents::Types::ActionStep, step_number: 7)
        instance.max_steps = 10
        logs = "Output"

        result = instance.send(:with_budget_reminder, action_step, logs)
        expect(result).to include("steps")
      end
    end

    context "with urgent budget situation" do
      it "returns URGENT message when no steps remain" do
        action_step = instance_double(Smolagents::Types::ActionStep, step_number: 10)
        instance.max_steps = 10
        logs = "Output"

        result = instance.send(:with_budget_reminder, action_step, logs)
        expect(result).to include("[URGENT:")
        expect(result).to include("LAST step")
        expect(result).to include("final_answer")
      end

      it "returns URGENT message when over budget" do
        action_step = instance_double(Smolagents::Types::ActionStep, step_number: 15)
        instance.max_steps = 10
        logs = "Output"

        result = instance.send(:with_budget_reminder, action_step, logs)
        expect(result).to include("[URGENT:")
      end
    end

    context "with log formatting" do
      it "preserves original logs as first line" do
        action_step = instance_double(Smolagents::Types::ActionStep, step_number: 8)
        instance.max_steps = 10
        logs = "First line\nSecond line"

        result = instance.send(:with_budget_reminder, action_step, logs)
        lines = result.split("\n")
        expect(lines[0]).to eq("First line")
        expect(lines[1]).to eq("Second line")
      end

      it "appends reminder on new line" do
        action_step = instance_double(Smolagents::Types::ActionStep, step_number: 8)
        instance.max_steps = 10
        logs = "Output"

        result = instance.send(:with_budget_reminder, action_step, logs)
        # At step 8 of 10, remaining = 10 - 8 - 1 = 1, so WARNING message
        expect(result).to include("Output\n[WARNING:")
      end

      it "handles multiline logs" do
        action_step = instance_double(Smolagents::Types::ActionStep, step_number: 9)
        instance.max_steps = 10
        logs = "Line 1\nLine 2\nLine 3"

        result = instance.send(:with_budget_reminder, action_step, logs)
        lines = result.split("\n")
        expect(lines.first).to eq("Line 1")
        expect(result).to include("[URGENT:")
      end
    end
  end

  describe "#calculate_remaining_steps" do
    it "calculates remaining steps correctly" do
      action_step = instance_double(Smolagents::Types::ActionStep, step_number: 3)
      instance.max_steps = 10

      remaining = instance.send(:calculate_remaining_steps, action_step)
      expect(remaining).to eq(6)  # 10 - 3 - 1
    end

    it "returns 0 when at max steps" do
      action_step = instance_double(Smolagents::Types::ActionStep, step_number: 9)
      instance.max_steps = 10

      remaining = instance.send(:calculate_remaining_steps, action_step)
      expect(remaining).to eq(0)
    end

    it "returns negative when over max steps" do
      action_step = instance_double(Smolagents::Types::ActionStep, step_number: 12)
      instance.max_steps = 10

      remaining = instance.send(:calculate_remaining_steps, action_step)
      expect(remaining).to eq(-3)
    end

    it "handles step_number = 0" do
      action_step = instance_double(Smolagents::Types::ActionStep, step_number: 0)
      instance.max_steps = 10

      remaining = instance.send(:calculate_remaining_steps, action_step)
      expect(remaining).to eq(9)  # 10 - 0 - 1
    end

    it "handles large max_steps" do
      action_step = instance_double(Smolagents::Types::ActionStep, step_number: 50)
      instance.max_steps = 1000

      remaining = instance.send(:calculate_remaining_steps, action_step)
      expect(remaining).to eq(949) # 1000 - 50 - 1
    end

    context "with nil step_number" do
      it "treats nil as 0" do
        action_step = instance_double(Smolagents::Types::ActionStep, step_number: nil)
        instance.max_steps = 10

        remaining = instance.send(:calculate_remaining_steps, action_step)
        expect(remaining).to eq(9)
      end
    end
  end

  describe "budget threshold messages" do
    it "sends no message when many steps remain" do
      action_step = instance_double(Smolagents::Types::ActionStep, step_number: 1)
      instance.max_steps = 20
      logs = "Output"

      result = instance.send(:with_budget_reminder, action_step, logs)
      expect(result).to eq("Output")
    end

    it "sends warning at step 8 of 10 (1 remaining)" do
      action_step = instance_double(Smolagents::Types::ActionStep, step_number: 8)
      instance.max_steps = 10
      logs = "Output"

      result = instance.send(:with_budget_reminder, action_step, logs)
      # remaining = 10 - 8 - 1 = 1
      expect(result).to include("[WARNING:")
    end

    it "sends budget message at step 7 of 10 (2 remaining)" do
      action_step = instance_double(Smolagents::Types::ActionStep, step_number: 7)
      instance.max_steps = 10
      logs = "Output"

      result = instance.send(:with_budget_reminder, action_step, logs)
      # remaining = 10 - 7 - 1 = 2
      expect(result).to include("[Budget: 2 steps remaining")
    end

    it "sends budget message at step 6 of 10 (3 remaining)" do
      action_step = instance_double(Smolagents::Types::ActionStep, step_number: 6)
      instance.max_steps = 10
      logs = "Output"

      result = instance.send(:with_budget_reminder, action_step, logs)
      # remaining = 10 - 6 - 1 = 3 (now shows message with new thresholds)
      expect(result).to include("[Budget: 3 steps remaining")
    end

    it "does not send budget message at step 5 of 10 (4 remaining)" do
      action_step = instance_double(Smolagents::Types::ActionStep, step_number: 5)
      instance.max_steps = 10
      logs = "Output"

      result = instance.send(:with_budget_reminder, action_step, logs)
      # remaining = 10 - 5 - 1 = 4 (edge of threshold)
      expect(result).to include("[Budget: 4 steps remaining")
    end

    it "does not send budget message with 5+ remaining" do
      action_step = instance_double(Smolagents::Types::ActionStep, step_number: 4)
      instance.max_steps = 10
      logs = "Output"

      result = instance.send(:with_budget_reminder, action_step, logs)
      # remaining = 10 - 4 - 1 = 5 (no message)
      expect(result).to eq("Output")
    end
  end

  describe "integration" do
    it "tracks budget throughout execution" do
      instance.max_steps = 8

      # Step 1 - plenty of room (remaining = 6, no message)
      result1 = instance.send(:with_budget_reminder,
                              instance_double(Smolagents::Types::ActionStep, step_number: 1),
                              "Output 1")
      expect(result1).to eq("Output 1")

      # Step 4 - getting low (remaining = 3, shows budget)
      result4 = instance.send(:with_budget_reminder,
                              instance_double(Smolagents::Types::ActionStep, step_number: 4),
                              "Output 4")
      expect(result4).to include("[Budget: 3 steps remaining")

      # Step 6 - warning (remaining = 1)
      result6 = instance.send(:with_budget_reminder,
                              instance_double(Smolagents::Types::ActionStep, step_number: 6),
                              "Output 6")
      expect(result6).to include("[WARNING:")

      # Step 8 - last step (remaining = -1)
      result8 = instance.send(:with_budget_reminder,
                              instance_double(Smolagents::Types::ActionStep, step_number: 8),
                              "Output 8")
      expect(result8).to include("[URGENT:")
    end

    it "handles budget reminder with real execution flow" do
      instance.max_steps = 3
      logs = "Executed search tool\nGot 5 results"

      # remaining = max_steps - step_number - 1 = 3 - 1 - 1 = 1 (triggers WARNING)
      result = instance.send(:with_budget_reminder,
                             instance_double(Smolagents::Types::ActionStep, step_number: 1),
                             logs)

      lines = result.split("\n")
      expect(lines.size).to be > 2 # Original logs plus reminder
      expect(result).to include("[WARNING:")
      expect(result).to include("Executed search")
    end
  end

  describe "context awareness signals" do
    let(:mock_memory) do
      instance_double("AgentMemory")
    end

    before do
      instance.memory = mock_memory
      instance.max_steps = nil # Disable step signals to isolate context tests
    end

    describe "#context_signal" do
      it "returns nil when memory doesn't respond to token_usage_percent" do
        instance.memory = Object.new
        expect(instance.send(:context_signal)).to be_nil
      end

      it "returns nil when token_usage_percent is nil (no budget configured)" do
        allow(mock_memory).to receive(:token_usage_percent).and_return(nil)
        expect(instance.send(:context_signal)).to be_nil
      end

      it "returns nil when usage is below 60%" do
        allow(mock_memory).to receive(:token_usage_percent).and_return(0.5)
        expect(instance.send(:context_signal)).to be_nil
      end

      it "returns informational message at 60-75% usage" do
        allow(mock_memory).to receive(:token_usage_percent).and_return(0.65)

        signal = instance.send(:context_signal)
        expect(signal).to include("[Context at 65%]")
      end

      it "returns warning at 75-90% usage" do
        allow(mock_memory).to receive(:token_usage_percent).and_return(0.80)

        signal = instance.send(:context_signal)
        expect(signal).to include("Context at 80%")
        expect(signal).to include("Consider summarizing")
      end

      it "returns urgent message at 90%+ usage" do
        allow(mock_memory).to receive(:token_usage_percent).and_return(0.95)

        signal = instance.send(:context_signal)
        expect(signal).to include("[URGENT: Context 90%+ full")
        expect(signal).to include("final_answer")
      end

      it "handles usage over 100%" do
        allow(mock_memory).to receive(:token_usage_percent).and_return(1.15)

        signal = instance.send(:context_signal)
        expect(signal).to include("[URGENT:")
      end
    end

    describe "combined step and context signals" do
      let(:action_step) { instance_double(Smolagents::Types::ActionStep, step_number: 7) }

      before do
        instance.max_steps = 10 # Re-enable step signals
      end

      it "includes both step budget and context signals when both apply" do
        allow(mock_memory).to receive(:token_usage_percent).and_return(0.85)

        result = instance.send(:with_budget_reminder, action_step, "Output")
        # Step 7 of 10: remaining = 2, shows budget message
        expect(result).to include("[Budget: 2 steps remaining")
        expect(result).to include("[Context at 85%")
      end

      it "shows only step signal when context usage is low" do
        allow(mock_memory).to receive(:token_usage_percent).and_return(0.30)

        result = instance.send(:with_budget_reminder, action_step, "Output")
        expect(result).to include("[Budget:")
        expect(result).not_to include("[Context")
      end

      it "shows only context signal when step budget is fine" do
        instance.max_steps = 100
        action_step = instance_double(Smolagents::Types::ActionStep, step_number: 5)
        allow(mock_memory).to receive(:token_usage_percent).and_return(0.80)

        result = instance.send(:with_budget_reminder, action_step, "Output")
        expect(result).not_to include("[Budget:")
        expect(result).to include("[Context at 80%")
      end

      it "preserves original logs with multiple signals" do
        allow(mock_memory).to receive(:token_usage_percent).and_return(0.92)

        result = instance.send(:with_budget_reminder, action_step, "Line 1\nLine 2")
        lines = result.split("\n")
        expect(lines[0]).to eq("Line 1")
        expect(lines[1]).to eq("Line 2")
        expect(result).to include("[URGENT:")
      end
    end

    describe "#context_signal_for" do
      it "returns correct thresholds" do
        expect(instance.send(:context_signal_for, 0.59)).to be_nil
        expect(instance.send(:context_signal_for, 0.60)).to include("60%")
        expect(instance.send(:context_signal_for, 0.74)).to include("74%")
        expect(instance.send(:context_signal_for, 0.75)).to include("Consider summarizing")
        expect(instance.send(:context_signal_for, 0.89)).to include("Consider summarizing")
        expect(instance.send(:context_signal_for, 0.90)).to include("[URGENT:")
      end
    end
  end
end
