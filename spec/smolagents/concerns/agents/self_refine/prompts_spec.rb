require "smolagents/concerns/agents/self_refine/prompts"

RSpec.describe Smolagents::Concerns::SelfRefine::Prompts do
  describe "CRITIQUE_SYSTEM constant" do
    it "exists and is a string" do
      expect(described_class::CRITIQUE_SYSTEM).to be_a(String)
      expect(described_class::CRITIQUE_SYSTEM).not_to be_empty
    end

    it "mentions code review" do
      expect(described_class::CRITIQUE_SYSTEM).to include("code reviewer")
    end
  end

  describe "REFINE_SYSTEM constant" do
    it "exists and is a string" do
      expect(described_class::REFINE_SYSTEM).to be_a(String)
      expect(described_class::REFINE_SYSTEM).not_to be_empty
    end
  end

  describe "#self_critique_feedback" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::SelfRefine::Prompts

        attr_accessor :model
      end
    end

    let(:instance) { test_class.new }
    let(:mock_model) { instance_double(Smolagents::Model) }

    before do
      instance.model = mock_model
    end

    it "returns RefinementFeedback with LGTM response" do
      allow(mock_model).to receive(:generate).and_return(
        Smolagents::ChatMessage.assistant("LGTM")
      )

      feedback = instance.send(:self_critique_feedback, "output", "task", 0)

      expect(feedback).to be_a(Smolagents::Types::RefinementFeedback)
      expect(feedback.iteration).to eq(0)
      expect(feedback.source).to eq(:self)
      expect(feedback.actionable).to be false
    end

    it "returns actionable feedback with issue/fix response" do
      allow(mock_model).to receive(:generate).and_return(
        Smolagents::ChatMessage.assistant("ISSUE: Missing error handling | FIX: Add rescue block")
      )

      feedback = instance.send(:self_critique_feedback, "output", "task", 1)

      expect(feedback).to be_a(Smolagents::Types::RefinementFeedback)
      expect(feedback.actionable).to be true
      expect(feedback.critique).to include("Missing error handling")
    end

    it "uses model to generate feedback" do
      allow(mock_model).to receive(:generate).and_return(
        Smolagents::ChatMessage.assistant("LGTM")
      )

      instance.send(:self_critique_feedback, "output", "task", 0)

      expect(mock_model).to have_received(:generate)
    end
  end

  describe "#build_critique_prompt" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::SelfRefine::Prompts
      end
    end

    let(:instance) { test_class.new }

    it "includes task and output" do
      prompt = instance.send(:build_critique_prompt, "my output", "my task")

      expect(prompt).to include("my task")
      expect(prompt).to include("my output")
    end

    it "truncates long output" do
      long_output = "x" * 1000
      prompt = instance.send(:build_critique_prompt, long_output, "task")

      expect(prompt.length).to be < 1000
    end
  end

  describe "#apply_refinement" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::SelfRefine::Prompts

        attr_accessor :model
      end
    end

    let(:instance) { test_class.new }
    let(:mock_model) { instance_double(Smolagents::Model) }

    before do
      instance.model = mock_model
    end

    it "returns refined output from model" do
      allow(mock_model).to receive(:generate).and_return(
        Smolagents::ChatMessage.assistant("fixed code here")
      )

      feedback = Smolagents::Types::RefinementFeedback.new(
        iteration: 0, source: :self, critique: "Fix the bug", actionable: true, confidence: 0.8
      )

      result = instance.send(:apply_refinement, "original code", feedback, "fix the code")

      expect(result).to eq("fixed code here")
    end
  end

  describe "#refinement_prompt" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::SelfRefine::Prompts
      end
    end

    let(:instance) { test_class.new }

    it "includes current output and feedback" do
      feedback = Smolagents::Types::RefinementFeedback.new(
        iteration: 0, source: :self, critique: "Add error handling", actionable: true, confidence: 0.7
      )

      prompt = instance.send(:refinement_prompt, "current code", feedback, "task")

      expect(prompt).to include("current code")
      expect(prompt).to include("Add error handling")
    end
  end

  describe "#parse_self_critique_response" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::SelfRefine::Prompts
      end
    end

    let(:instance) { test_class.new }

    it "parses LGTM as non-actionable" do
      feedback = instance.send(:parse_self_critique_response, "LGTM", 0)

      expect(feedback.actionable).to be false
      expect(feedback.confidence).to eq(0.8)
    end

    it "parses LOOKS GOOD as non-actionable" do
      feedback = instance.send(:parse_self_critique_response, "Looks Good To Me", 0)

      expect(feedback.actionable).to be false
    end

    it "parses issue/fix format as actionable" do
      feedback = instance.send(:parse_self_critique_response,
                               "ISSUE: Variable undefined | FIX: Initialize variable", 0)

      expect(feedback.actionable).to be true
      expect(feedback.critique).to include("Variable undefined")
      expect(feedback.critique).to include("Initialize variable")
    end

    it "handles unstructured feedback" do
      feedback = instance.send(:parse_self_critique_response,
                               "This code has some issues that need to be addressed", 0)

      expect(feedback).to be_a(Smolagents::Types::RefinementFeedback)
      expect(feedback.confidence).to eq(0.5)
    end
  end
end
