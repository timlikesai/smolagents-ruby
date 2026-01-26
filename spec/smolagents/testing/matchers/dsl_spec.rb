require "spec_helper"

RSpec.describe Smolagents::Testing::Matchers::DSL do
  describe "#define_predicate_matcher" do
    let(:test_class) do
      Class.new do
        extend Smolagents::Testing::Matchers::DSL
      end
    end

    it "creates a matcher that calls the predicate method" do
      test_class.define_predicate_matcher(:be_active, :active?)
      # Matcher is defined on RSpec, verify through respond_to
      expect(respond_to?(:be_active)).to be true
    end
  end

  describe "#define_threshold_matcher" do
    let(:test_class) do
      Class.new do
        extend Smolagents::Testing::Matchers::DSL
      end
    end

    it "creates a matcher for threshold comparisons" do
      test_class.define_threshold_matcher(:have_score, :score)
      expect(respond_to?(:have_score)).to be true
    end
  end

  describe "#define_content_matcher" do
    let(:test_class) do
      Class.new do
        extend Smolagents::Testing::Matchers::DSL
      end
    end

    it "creates a matcher for content matching" do
      test_class.define_content_matcher(:have_body, &:body)
      expect(respond_to?(:have_body)).to be true
    end
  end
end

RSpec.describe Smolagents::Testing::Matchers::ThresholdComparison do
  describe ".compare" do
    it "returns true when value >= threshold for non-hash" do
      expect(described_class.compare(5, 3)).to be true
      expect(described_class.compare(3, 3)).to be true
      expect(described_class.compare(2, 3)).to be false
    end

    it "handles at_least comparison" do
      expect(described_class.compare(5, { at_least: 3 })).to be true
      expect(described_class.compare(3, { at_least: 3 })).to be true
      expect(described_class.compare(2, { at_least: 3 })).to be false
    end

    it "handles at_most comparison" do
      expect(described_class.compare(2, { at_most: 3 })).to be true
      expect(described_class.compare(3, { at_most: 3 })).to be true
      expect(described_class.compare(4, { at_most: 3 })).to be false
    end

    it "handles exactly comparison with tolerance" do
      expect(described_class.compare(3.0, { exactly: 3.0 })).to be true
      expect(described_class.compare(3.0005, { exactly: 3.0 })).to be true
      expect(described_class.compare(3.01, { exactly: 3.0 })).to be false
    end

    it "handles above comparison" do
      expect(described_class.compare(4, { above: 3 })).to be true
      expect(described_class.compare(3, { above: 3 })).to be false
    end

    it "handles below comparison" do
      expect(described_class.compare(2, { below: 3 })).to be true
      expect(described_class.compare(3, { below: 3 })).to be false
    end

    it "returns true for empty hash" do
      expect(described_class.compare(5, {})).to be true
    end
  end

  describe ".format" do
    it "formats non-hash as >= threshold" do
      expect(described_class.format(5)).to eq(">= 5")
    end

    it "formats at_least" do
      expect(described_class.format({ at_least: 3 })).to eq(">= 3")
    end

    it "formats at_most" do
      expect(described_class.format({ at_most: 5 })).to eq("<= 5")
    end

    it "formats exactly" do
      expect(described_class.format({ exactly: 3 })).to eq("== 3")
    end

    it "formats above" do
      expect(described_class.format({ above: 2 })).to eq("> 2")
    end

    it "formats below" do
      expect(described_class.format({ below: 4 })).to eq("< 4")
    end

    it "formats empty hash as string" do
      expect(described_class.format({})).to eq("{}")
    end
  end
end

RSpec.describe Smolagents::Testing::Matchers::ContentMatch do
  describe ".matches?" do
    it "returns true when no options" do
      expect(described_class.matches?("hello world", {})).to be true
    end

    it "matches containing option" do
      expect(described_class.matches?("hello world", { containing: "world" })).to be true
      expect(described_class.matches?("hello world", { containing: "foo" })).to be false
    end

    it "matches pattern option" do
      expect(described_class.matches?("hello123", { matching: /\d+/ })).to be true
      expect(described_class.matches?("hello", { matching: /\d+/ })).to be false
    end

    it "matches both options together" do
      expect(described_class.matches?("hello123", { containing: "hello", matching: /\d+/ })).to be true
      expect(described_class.matches?("hello", { containing: "hello", matching: /\d+/ })).to be false
      expect(described_class.matches?("123", { containing: "hello", matching: /\d+/ })).to be false
    end
  end

  describe ".matches_containing?" do
    it "returns true when option not present" do
      expect(described_class.matches_containing?("text", {})).to be true
    end

    it "checks if content contains substring" do
      expect(described_class.matches_containing?("hello world", { containing: "world" })).to be true
      expect(described_class.matches_containing?("hello world", { containing: "xyz" })).to be false
    end
  end

  describe ".matches_pattern?" do
    it "returns true when option not present" do
      expect(described_class.matches_pattern?("text", {})).to be true
    end

    it "checks if content matches pattern" do
      expect(described_class.matches_pattern?("abc123", { matching: /\d+/ })).to be true
      expect(described_class.matches_pattern?("abc", { matching: /\d+/ })).to be false
    end
  end
end
