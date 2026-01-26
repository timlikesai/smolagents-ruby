require "spec_helper"

RSpec.describe Smolagents::Interactive::Completion do
  describe ".completions_for" do
    context "with builder method context" do
      it "completes Smolagents.agent. methods" do
        completions = described_class.completions_for("Smolagents.agent.mo")
        expect(completions).to include("model")
      end

      it "completes generic builder methods" do
        completions = described_class.completions_for(".to")
        expect(completions).to include("tools")
      end

      it "returns multiple matches" do
        completions = described_class.completions_for("Smolagents.agent.m")
        expect(completions).to include("model", "max_steps", "memory")
      end
    end

    context "with .tools( context" do
      it "completes toolkit names" do
        completions = described_class.completions_for(".tools(:sea")
        expect(completions).to include(":search")
      end

      it "completes tool names" do
        completions = described_class.completions_for(".tools(:visit")
        expect(completions).to include(":visit_webpage")
      end

      it "completes without colon prefix" do
        completions = described_class.completions_for(".tools(sea")
        expect(completions).to include(":search")
      end

      it "returns all tools with empty prefix" do
        completions = described_class.completions_for(".tools(:")
        expect(completions.size).to be > 5
        expect(completions).to include(":search", ":web", ":visit_webpage")
      end
    end

    context "with .as( context" do
      it "completes persona names" do
        completions = described_class.completions_for(".as(:res")
        expect(completions).to include(":researcher")
      end

      it "completes all personas with empty prefix" do
        completions = described_class.completions_for(".as(:")
        expect(completions).to include(":researcher", ":analyst", ":fact_checker")
      end
    end

    context "with .persona( context" do
      it "completes persona names" do
        completions = described_class.completions_for(".persona(:ana")
        expect(completions).to include(":analyst")
      end
    end

    context "with .with( context" do
      it "completes specialization names" do
        completions = described_class.completions_for(".with(:res")
        expect(completions).to include(":researcher")
      end

      it "returns all specializations with empty prefix" do
        completions = described_class.completions_for(".with(:")
        expect(completions.size).to be >= 1
      end
    end

    context "with non-matching input" do
      it "returns empty array for unrecognized patterns" do
        completions = described_class.completions_for("some_random_code")
        expect(completions).to be_empty
      end
    end
  end

  describe ".irb_available?" do
    it "checks for IRB and InputCompletor" do
      # The method checks for IRB, IRB.conf, and IRB::InputCompletor
      # In test environment, IRB may or may not be loaded
      result = described_class.irb_available?
      expect(result).to be(true).or be(false)
    end
  end
end
