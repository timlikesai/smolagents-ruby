require "spec_helper"

RSpec.describe Smolagents::Concerns::ExecutionOracle::ConfidenceScorer do
  subject(:scorer) { test_class.new }

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ExecutionOracle::ConfidenceScorer
    end
  end

  describe "#calculate_confidence" do
    context "with syntax errors" do
      it "returns high confidence with details" do
        details = { unexpected: ")", expecting: "end" }
        score = scorer.calculate_confidence(:syntax_error, details)

        expect(score).to eq(0.9)
      end

      it "returns lower confidence without details" do
        details = {}
        score = scorer.calculate_confidence(:syntax_error, details)

        expect(score).to eq(0.7)
      end
    end

    context "with name errors" do
      it "returns high confidence when undefined_name present" do
        details = { undefined_name: "some_var" }
        score = scorer.calculate_confidence(:name_error, details)

        expect(score).to eq(0.85)
      end

      it "returns lower confidence without undefined_name" do
        details = {}
        score = scorer.calculate_confidence(:name_error, details)

        expect(score).to eq(0.6)
      end
    end

    context "with no method errors" do
      it "returns high confidence with undefined_method" do
        details = { undefined_method: "foo", receiver_class: "String" }
        score = scorer.calculate_confidence(:no_method_error, details)

        expect(score).to eq(0.85)
      end

      it "returns lower confidence without method details" do
        details = {}
        score = scorer.calculate_confidence(:no_method_error, details)

        expect(score).to eq(0.6)
      end
    end

    context "with type errors" do
      it "returns high confidence with both types" do
        details = { from_type: "String", to_type: "Integer" }
        score = scorer.calculate_confidence(:type_error, details)

        expect(score).to eq(0.8)
      end

      it "returns lower confidence with missing types" do
        details = { from_type: "String" }
        score = scorer.calculate_confidence(:type_error, details)

        expect(score).to eq(0.5)
      end
    end

    context "with argument errors" do
      it "returns high confidence with given and expected" do
        details = { given: 2, expected: "3" }
        score = scorer.calculate_confidence(:argument_error, details)

        expect(score).to eq(0.9)
      end

      it "returns lower confidence without details" do
        details = {}
        score = scorer.calculate_confidence(:argument_error, details)

        expect(score).to eq(0.6)
      end
    end

    context "with tool errors" do
      it "returns high confidence with tool_name" do
        details = { tool_name: "search_tool" }
        score = scorer.calculate_confidence(:tool_error, details)

        expect(score).to eq(0.95)
      end

      it "returns lower confidence without tool_name" do
        details = {}
        score = scorer.calculate_confidence(:tool_error, details)

        expect(score).to eq(0.7)
      end
    end

    context "with timeout errors" do
      it "always returns 0.8" do
        score1 = scorer.calculate_confidence(:timeout, {})
        score2 = scorer.calculate_confidence(:timeout, { extra: "data" })

        expect(score1).to eq(0.8)
        expect(score2).to eq(0.8)
      end
    end

    context "with memory limit errors" do
      it "always returns 0.8" do
        score = scorer.calculate_confidence(:memory_limit, {})
        expect(score).to eq(0.8)
      end
    end

    context "with operation limit errors" do
      it "always returns 0.8" do
        score = scorer.calculate_confidence(:operation_limit, {})
        expect(score).to eq(0.8)
      end
    end

    context "with unknown error categories" do
      it "returns default 0.5 for unknown categories" do
        score = scorer.calculate_confidence(:unknown_error, {})
        expect(score).to eq(0.5)
      end

      it "returns 0.5 regardless of details" do
        score = scorer.calculate_confidence(:unknown_error, { data: "test" })
        expect(score).to eq(0.5)
      end
    end

    context "confidence score range" do
      it "returns scores between 0 and 1" do
        errors = [
          [:syntax_error, {}],
          [:name_error, {}],
          [:no_method_error, { undefined_method: "foo" }],
          [:type_error, { from_type: "A", to_type: "B" }],
          [:argument_error, { given: 1, expected: "2" }],
          [:tool_error, { tool_name: "tool" }],
          [:timeout, {}],
          [:memory_limit, {}],
          [:operation_limit, {}],
          [:unknown, {}]
        ]

        errors.each do |category, details|
          score = scorer.calculate_confidence(category, details)
          expect(score).to be_between(0.0, 1.0)
        end
      end
    end
  end

  describe "confidence rules" do
    it "defines CONFIDENCE_RULES" do
      rules = Smolagents::Concerns::ExecutionOracle::ConfidenceScorer::CONFIDENCE_RULES
      expect(rules).to be_a(Hash)
    end

    it "has rules for all major error types" do
      rules = Smolagents::Concerns::ExecutionOracle::ConfidenceScorer::CONFIDENCE_RULES
      expect(rules).to have_key(:syntax_error)
      expect(rules).to have_key(:name_error)
      expect(rules).to have_key(:no_method_error)
      expect(rules).to have_key(:tool_error)
    end

    it "all rules are callable" do
      rules = Smolagents::Concerns::ExecutionOracle::ConfidenceScorer::CONFIDENCE_RULES
      rules.each_value do |rule|
        expect(rule).to respond_to(:call)
      end
    end
  end

  describe "scoring strategies" do
    it "higher confidence for specific details" do
      # With details: 0.9
      # Without details: 0.7
      with_details = scorer.calculate_confidence(:syntax_error, { unexpected: ")" })
      without_details = scorer.calculate_confidence(:syntax_error, {})

      expect(with_details).to be > without_details
    end

    it "higher confidence for tool errors" do
      tool_confidence = scorer.calculate_confidence(:tool_error, { tool_name: "search" })
      other_confidence = scorer.calculate_confidence(:syntax_error, { unexpected: ")" })

      expect(tool_confidence).to be > other_confidence
    end

    it "consistent scores for same input" do
      details = { undefined_method: "foo" }
      score1 = scorer.calculate_confidence(:no_method_error, details)
      score2 = scorer.calculate_confidence(:no_method_error, details)

      expect(score1).to eq(score2)
    end
  end

  describe "use cases" do
    it "prioritizes tool errors" do
      tool_score = scorer.calculate_confidence(:tool_error, { tool_name: "missing" })
      syntax_score = scorer.calculate_confidence(:syntax_error, { unexpected: ")" })
      other_score = scorer.calculate_confidence(:unknown_error, {})

      expect(tool_score).to be > syntax_score
      expect(syntax_score).to be > other_score
    end

    it "timeout errors have moderate confidence" do
      timeout_score = scorer.calculate_confidence(:timeout, {})
      low_score = scorer.calculate_confidence(:unknown_error, {})
      high_score = scorer.calculate_confidence(:tool_error, { tool_name: "x" })

      expect(timeout_score).to be > low_score
      expect(timeout_score).to be < high_score
    end

    it "detailed errors more confident than vague" do
      detailed_arg_error = scorer.calculate_confidence(:argument_error, { given: 2, expected: "3" })
      vague_arg_error = scorer.calculate_confidence(:argument_error, {})

      expect(detailed_arg_error).to be > vague_arg_error
    end
  end
end
