require "spec_helper"

RSpec.describe Smolagents::Builders::GoalsConcern do
  let(:builder) { Smolagents::Builders::AgentBuilder.create }

  describe "#goals" do
    context "with no arguments" do
      it "enables goals with defaults" do
        result = builder.goals

        expect(result.configuration[:goal_config].enabled).to be true
        expect(result.configuration[:goal_config].visible).to be false
      end
    end

    context "with boolean argument" do
      it "enables goals with true" do
        result = builder.goals(true)
        expect(result.configuration[:goal_config].enabled).to be true
      end

      it "disables goals with false" do
        result = builder.goals(false)
        expect(result.configuration[:goal_config].enabled).to be false
      end
    end

    context "with symbol argument" do
      it "enables goals with :enabled" do
        result = builder.goals(:enabled)
        expect(result.configuration[:goal_config].enabled).to be true
      end

      it "disables goals with :disabled" do
        result = builder.goals(:disabled)
        expect(result.configuration[:goal_config].enabled).to be false
      end

      it "enables goals with :on" do
        result = builder.goals(:on)
        expect(result.configuration[:goal_config].enabled).to be true
      end

      it "disables goals with :off" do
        result = builder.goals(:off)
        expect(result.configuration[:goal_config].enabled).to be false
      end
    end

    context "with visible option" do
      it "sets visibility when enabled" do
        result = builder.goals(visible: true)

        expect(result.configuration[:goal_config].enabled).to be true
        expect(result.configuration[:goal_config].visible).to be true
      end
    end

    context "with invalid argument" do
      it "raises ArgumentError" do
        expect { builder.goals(:invalid) }.to raise_error(ArgumentError, /Invalid goals argument/)
      end
    end

    it "returns new builder (immutability)" do
      result = builder.goals
      expect(result).not_to equal(builder)
      expect(result.configuration[:goal_config]).not_to be_nil
      expect(builder.configuration[:goal_config]).to be_nil
    end
  end
end
