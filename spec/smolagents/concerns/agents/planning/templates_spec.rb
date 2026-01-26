require "smolagents/concerns/agents/planning/templates"

RSpec.describe Smolagents::Concerns::Planning::Templates do
  describe "TEMPLATES constant" do
    subject { described_class::TEMPLATES }

    it "is frozen" do
      expect(subject).to be_frozen
    end

    it "includes initial_plan template" do
      expect(subject).to have_key(:initial_plan)
    end

    it "includes update_plan_pre template" do
      expect(subject).to have_key(:update_plan_pre)
    end

    it "includes update_plan_post template" do
      expect(subject).to have_key(:update_plan_post)
    end

    it "includes planning_system template" do
      expect(subject).to have_key(:planning_system)
    end
  end

  describe "initial_plan template" do
    subject { described_class::TEMPLATES[:initial_plan] }

    it "is a non-empty string" do
      expect(subject).to be_a(String)
      expect(subject).not_to be_empty
    end

    it "contains task placeholder" do
      expect(subject).to include("%<task>s")
    end

    it "contains tools placeholder" do
      expect(subject).to include("%<tools>s")
    end

    it "includes plan creation instructions" do
      expect(subject).to include("plan")
    end

    it "mentions step count guidance (3-5)" do
      expect(subject).to include("3-5")
    end

    it "emphasizes concrete steps" do
      expect(subject).to match(/concrete|specific/i)
    end

    it "references available tools" do
      expect(subject).to include("Available tools")
    end

    it "can be formatted with task and tools" do
      formatted = format(subject, task: "Find Python docs", tools: "- search\n- parse")
      expect(formatted).to include("Find Python docs")
      expect(formatted).to include("search")
    end
  end

  describe "update_plan_pre template" do
    subject { described_class::TEMPLATES[:update_plan_pre] }

    it "is a non-empty string" do
      expect(subject).to be_a(String)
      expect(subject).not_to be_empty
    end

    it "contains task placeholder" do
      expect(subject).to include("%<task>s")
    end

    it "mentions review and progress" do
      expect(subject).to match(/review|progress/i)
    end

    it "can be formatted with task" do
      formatted = format(subject, task: "Find Ruby docs")
      expect(formatted).to include("Find Ruby docs")
    end
  end

  describe "update_plan_post template" do
    subject { described_class::TEMPLATES[:update_plan_post] }

    it "is a non-empty string" do
      expect(subject).to be_a(String)
      expect(subject).not_to be_empty
    end

    it "contains steps placeholder" do
      expect(subject).to include("%<steps>s")
    end

    it "contains observations placeholder" do
      expect(subject).to include("%<observations>s")
    end

    it "contains plan placeholder" do
      expect(subject).to include("%<plan>s")
    end

    it "includes progress context" do
      expect(subject).to match(/progress/i)
    end

    it "mentions plan updates" do
      expect(subject).to match(/update/i)
    end

    it "references current plan" do
      expect(subject).to include("Current plan")
    end

    it "provides choice: confirm or update" do
      expect(subject).to match(/(Confirm|Update|either)/i)
    end

    it "can be formatted with all placeholders" do
      formatted = format(subject,
                         task: "Task",
                         steps: "1. Search\n2. Parse",
                         observations: "Found results",
                         plan: "Initial plan")
      expect(formatted).to include("Found results")
      expect(formatted).to include("Search")
    end
  end

  describe "planning_system template" do
    subject { described_class::TEMPLATES[:planning_system] }

    it "is a non-empty string" do
      expect(subject).to be_a(String)
      expect(subject).not_to be_empty
    end

    it "is a single line (whitespace normalized)" do
      # The template uses gsub to normalize whitespace
      expect(subject).not_to include("\n")
    end

    it "describes the planning assistant role" do
      expect(subject).to match(/planning|assistant/i)
    end

    it "emphasizes concrete steps" do
      expect(subject).to match(/concrete|specific/i)
    end

    it "mentions tool mapping" do
      expect(subject).to match(/tools|actions/i)
    end

    it "has no format placeholders" do
      expect(subject).not_to include("%<")
    end

    it "can be used directly without formatting" do
      # Should not raise when used as is
      expect(subject).to be_a(String)
    end
  end

  describe "template formatting" do
    it "can format initial_plan with all required placeholders" do
      template = described_class::TEMPLATES[:initial_plan]
      formatted = format(template, task: "Find Python docs", tools: "search, parse")

      expect(formatted).to include("Find Python docs")
      expect(formatted).to include("search")
      expect(formatted).not_to include("%<task>s")
      expect(formatted).not_to include("%<tools>s")
    end

    it "can format update_plan_post with all required placeholders" do
      template = described_class::TEMPLATES[:update_plan_post]
      formatted = format(template,
                         steps: "1. Test",
                         observations: "Test obs",
                         plan: "Test plan")

      expect(formatted).to include("1. Test")
      expect(formatted).to include("Test obs")
      expect(formatted).to include("Test plan")
      expect(formatted).not_to include("%<")
    end

    it "can format update_plan_pre with task placeholder" do
      template = described_class::TEMPLATES[:update_plan_pre]
      formatted = format(template, task: "My task")

      expect(formatted).to include("My task")
      expect(formatted).not_to include("%<task>s")
    end
  end

  describe "template consistency" do
    let(:templates) { described_class::TEMPLATES }

    it "all templates are strings" do
      templates.each_value do |template|
        expect(template).to be_a(String)
      end
    end

    it "all templates are non-empty" do
      templates.each_value do |template|
        expect(template).not_to be_empty
      end
    end

    it "planning_system has no placeholders" do
      template = templates[:planning_system]
      expect(template).not_to include("%<")
    end

    it "other templates have appropriate placeholders" do
      expect(templates[:initial_plan]).to include("%<task>s")
      expect(templates[:initial_plan]).to include("%<tools>s")

      expect(templates[:update_plan_pre]).to include("%<task>s")

      # update_plan_post uses steps, observations, plan - but NOT task
      expect(templates[:update_plan_post]).to include("%<steps>s")
      expect(templates[:update_plan_post]).to include("%<observations>s")
      expect(templates[:update_plan_post]).to include("%<plan>s")
    end
  end

  describe "Pre-Act alignment" do
    it "initial_plan asks for 3-5 steps per research" do
      template = described_class::TEMPLATES[:initial_plan]
      expect(template).to include("3-5")
    end

    it "planning_system emphasizes concrete steps" do
      template = described_class::TEMPLATES[:planning_system]
      expect(template).to match(/concrete/)
    end

    it "planning_system focuses on tool mapping" do
      template = described_class::TEMPLATES[:planning_system]
      expect(template).to match(/tools/)
    end

    it "templates avoid abstract strategies" do
      # Planning should focus on concrete actions
      templates = described_class::TEMPLATES
      expect(templates[:planning_system]).to match(/concrete|actionable/)
    end
  end

  describe "template usage patterns" do
    let(:templates) { described_class::TEMPLATES }

    it "supports format with string interpolation" do
      # This is how templates are used in the codebase
      initial = templates[:initial_plan]
      result = format(initial, task: "Test", tools: "search")
      expect(result).to be_a(String)
    end

    it "planning_system can be used directly" do
      system = templates[:planning_system]
      # Should be ready to use as-is
      expect(system).to match(/strategic|planning/i)
    end

    it "preserves structure through formatting" do
      template = templates[:update_plan_post]
      formatted = format(template,
                         task: "T",
                         steps: "S",
                         observations: "O",
                         plan: "P")

      # Should still have the structure (sections)
      expect(formatted).to include("Progress")
      expect(formatted).to include("Latest observations")
    end
  end
end
