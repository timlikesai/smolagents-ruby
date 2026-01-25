require "spec_helper"

RSpec.describe Smolagents::Security::SpawnValidation do
  describe ".new with allowed: true" do
    subject(:validation) { described_class.new(allowed: true, violations: [].freeze) }

    it "creates an allowed validation" do
      expect(validation.allowed).to be true
    end

    it "has empty violations" do
      expect(validation.violations).to be_empty
    end
  end

  describe ".new with allowed: false" do
    subject(:validation) do
      v1 = Smolagents::Security::SpawnViolation.depth_exceeded(current: 3, max: 2)
      v2 = Smolagents::Security::SpawnViolation.unauthorized_tool(:search)
      described_class.new(allowed: false, violations: [v1, v2].freeze)
    end

    it "creates a denied validation" do
      expect(validation.allowed).to be false
    end

    it "contains violations" do
      expect(validation.violations.size).to eq(2)
    end

    it "preserves violation types" do
      expect(validation.violations.map(&:type)).to include(:depth_exceeded, :unauthorized_tool)
    end
  end

  describe "#allowed?" do
    it "returns true when allowed is true" do
      validation = described_class.new(allowed: true, violations: [].freeze)
      expect(validation.allowed?).to be true
    end

    it "returns false when allowed is false" do
      violation = Smolagents::Security::SpawnViolation.depth_exceeded(current: 3, max: 2)
      validation = described_class.new(allowed: false, violations: [violation].freeze)
      expect(validation.allowed?).to be false
    end
  end

  describe "#denied?" do
    it "returns false when allowed is true" do
      validation = described_class.new(allowed: true, violations: [].freeze)
      expect(validation.denied?).to be false
    end

    it "returns true when allowed is false" do
      violation = Smolagents::Security::SpawnViolation.depth_exceeded(current: 3, max: 2)
      validation = described_class.new(allowed: false, violations: [violation].freeze)
      expect(validation.denied?).to be true
    end
  end

  describe "#to_error_message" do
    it "returns nil when allowed" do
      validation = described_class.new(allowed: true, violations: [].freeze)
      expect(validation.to_error_message).to be_nil
    end

    it "returns error message when denied" do
      violation = Smolagents::Security::SpawnViolation.depth_exceeded(current: 3, max: 2)
      validation = described_class.new(allowed: false, violations: [violation].freeze)
      message = validation.to_error_message
      expect(message).not_to be_nil
    end

    it "includes 'Spawn denied' header" do
      violation = Smolagents::Security::SpawnViolation.depth_exceeded(current: 3, max: 2)
      validation = described_class.new(allowed: false, violations: [violation].freeze)
      message = validation.to_error_message
      expect(message).to include("Spawn denied:")
    end

    it "includes violation messages" do
      violation = Smolagents::Security::SpawnViolation.depth_exceeded(current: 3, max: 2)
      validation = described_class.new(allowed: false, violations: [violation].freeze)
      message = validation.to_error_message
      expect(message).to include("Depth limit exceeded")
    end

    it "formats each violation with bullet point" do
      v1 = Smolagents::Security::SpawnViolation.depth_exceeded(current: 3, max: 2)
      v2 = Smolagents::Security::SpawnViolation.unauthorized_tool(:database)
      validation = described_class.new(allowed: false, violations: [v1, v2].freeze)
      message = validation.to_error_message
      expect(message).to include("  - ")
    end

    it "includes all violations in message" do
      v1 = Smolagents::Security::SpawnViolation.depth_exceeded(current: 3, max: 2)
      v2 = Smolagents::Security::SpawnViolation.unauthorized_tool(:database)
      v3 = Smolagents::Security::SpawnViolation.steps_exceeded(requested: 50, max_per_agent: 30, remaining: 10)
      validation = described_class.new(allowed: false, violations: [v1, v2, v3].freeze)
      message = validation.to_error_message
      # Count bullet points
      bullet_count = message.scan("  - ").count
      expect(bullet_count).to eq(3)
    end

    it "joins violations with newlines" do
      v1 = Smolagents::Security::SpawnViolation.depth_exceeded(current: 3, max: 2)
      v2 = Smolagents::Security::SpawnViolation.unauthorized_tool(:search)
      validation = described_class.new(allowed: false, violations: [v1, v2].freeze)
      message = validation.to_error_message
      expect(message).to include("\n")
    end
  end

  describe "pattern matching with deconstruct_keys" do
    it "supports pattern matching for allowed validation" do
      validation = described_class.new(allowed: true, violations: [].freeze)
      matched = case validation
                in { allowed: true, violations: [] }
                  true
                else
                  false
                end
      expect(matched).to be true
    end

    it "supports pattern matching for denied validation" do
      violation = Smolagents::Security::SpawnViolation.depth_exceeded(current: 3, max: 2)
      validation = described_class.new(allowed: false, violations: [violation].freeze)
      matched = case validation
                in { allowed: false, violations: violations } if violations.any? { |v| v.type == :depth_exceeded }
                  true
                else
                  false
                end
      expect(matched).to be true
    end

    it "deconstruct_keys returns allowed and violations" do
      validation = described_class.new(allowed: true, violations: [].freeze)
      keys = validation.deconstruct_keys(nil)
      expect(keys).to have_key(:allowed)
      expect(keys).to have_key(:violations)
    end
  end

  describe "immutability" do
    it "is immutable (Data.define)" do
      validation = described_class.new(allowed: true, violations: [].freeze)
      expect { validation.allowed = false }.to raise_error(NoMethodError)
    end

    it "prevents modification of violations array" do
      violation = Smolagents::Security::SpawnViolation.depth_exceeded(current: 3, max: 2)
      validation = described_class.new(allowed: false, violations: [violation].freeze)
      new_violation = Smolagents::Security::SpawnViolation.unauthorized_tool(:search)
      expect { validation.violations << new_violation }.to raise_error(FrozenError)
    end
  end

  describe "integration scenarios" do
    it "represents a successful spawn validation" do
      validation = described_class.new(allowed: true, violations: [].freeze)
      expect(validation.allowed?).to be true
      expect(validation.denied?).to be false
      expect(validation.to_error_message).to be_nil
    end

    it "represents a spawn denied by depth limit" do
      violation = Smolagents::Security::SpawnViolation.depth_exceeded(current: 5, max: 2)
      validation = described_class.new(allowed: false, violations: [violation].freeze)
      expect(validation.allowed?).to be false
      expect(validation.denied?).to be true
      expect(validation.to_error_message).to include("Depth limit exceeded")
    end

    it "represents a spawn denied by tool restriction" do
      violation = Smolagents::Security::SpawnViolation.unauthorized_tool(:dangerous_tool)
      validation = described_class.new(allowed: false, violations: [violation].freeze)
      expect(validation.denied?).to be true
      message = validation.to_error_message
      expect(message).to include("dangerous_tool")
    end

    it "represents a spawn denied by step budget" do
      violation = Smolagents::Security::SpawnViolation.steps_exceeded(requested: 100, max_per_agent: 50, remaining: 10)
      validation = described_class.new(allowed: false, violations: [violation].freeze)
      expect(validation.denied?).to be true
      message = validation.to_error_message
      expect(message).to include("Steps exceeded")
    end

    it "represents multiple violations" do
      v1 = Smolagents::Security::SpawnViolation.depth_exceeded(current: 5, max: 2)
      v2 = Smolagents::Security::SpawnViolation.unauthorized_tool(:restricted)
      validation = described_class.new(allowed: false, violations: [v1, v2].freeze)
      message = validation.to_error_message
      expect(message).to include("Depth limit exceeded")
      expect(message).to include("Tool :restricted")
    end

    it "can be used as a boolean in conditionals" do
      validation_allowed = described_class.new(allowed: true, violations: [].freeze)
      validation_denied = described_class.new(
        allowed: false,
        violations: [Smolagents::Security::SpawnViolation.depth_exceeded(current: 3, max: 2)].freeze
      )

      expect(validation_allowed.allowed?).to be true
      expect(validation_denied.denied?).to be true
    end
  end
end
