require "spec_helper"

RSpec.describe Smolagents::Concerns::CritiqueParsing do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::CritiqueParsing
    end
  end
  let(:instance) { test_class.new }

  describe "#parse_critique_response" do
    describe "approval patterns" do
      it "detects APPROVED" do
        result = instance.parse_critique_response("APPROVED - no issues found", 1)

        expect(result.actionable).to be false
        expect(result.confidence).to eq(0.9)
        expect(result.critique).to include("approved")
      end

      it "detects LGTM" do
        result = instance.parse_critique_response("LGTM", 2)

        expect(result.actionable).to be false
        expect(result.confidence).to eq(0.9)
      end

      it "detects LOOKS GOOD" do
        result = instance.parse_critique_response("Looks good to me!", 1)

        expect(result.actionable).to be false
        expect(result.confidence).to eq(0.9)
      end

      it "is case-insensitive" do
        result = instance.parse_critique_response("approved", 1)

        expect(result.actionable).to be false
      end
    end

    describe "ISSUE/FIX patterns" do
      it "parses structured issue and fix" do
        content = "ISSUE: Variable not defined | FIX: Add variable declaration"
        result = instance.parse_critique_response(content, 1)

        expect(result.actionable).to be true
        expect(result.confidence).to eq(0.8)
        expect(result.critique).to include("Variable not defined")
        expect(result.critique).to include("Add variable declaration")
      end

      it "handles multiline ISSUE/FIX" do
        content = <<~TEXT
          ISSUE: The function doesn't handle errors
          | FIX: Add try-catch block
        TEXT

        result = instance.parse_critique_response(content, 1)

        expect(result.actionable).to be true
      end
    end

    describe "unclear feedback" do
      it "handles unstructured feedback" do
        content = "There are some issues with the error handling that should be addressed."
        result = instance.parse_critique_response(content, 1)

        expect(result.confidence).to eq(0.5)
        expect(result.critique).to include("error handling")
      end

      it "truncates long feedback to 200 characters" do
        content = "x" * 300
        result = instance.parse_critique_response(content, 1)

        expect(result.critique.length).to eq(200)
      end

      it "detects actionable content heuristically" do
        long_feedback = "The code has a bug where the variable is not properly initialized " \
                        "before being used in the loop."
        result = instance.parse_critique_response(long_feedback, 1)

        expect(result.actionable).to be true
      end

      it "detects non-actionable short feedback" do
        result = instance.parse_critique_response("OK", 1)

        expect(result.actionable).to be false
      end
    end

    describe "source parameter" do
      it "defaults to :self" do
        result = instance.parse_critique_response("APPROVED", 1)

        expect(result.source).to eq(:self)
      end

      it "accepts custom source" do
        result = instance.parse_critique_response("APPROVED", 1, source: :execution)

        expect(result.source).to eq(:execution)
      end

      it "accepts :evaluation source" do
        result = instance.parse_critique_response("APPROVED", 1, source: :evaluation)

        expect(result.source).to eq(:evaluation)
      end
    end

    describe "iteration tracking" do
      it "preserves iteration number" do
        result = instance.parse_critique_response("APPROVED", 5)

        expect(result.iteration).to eq(5)
      end
    end
  end
end
