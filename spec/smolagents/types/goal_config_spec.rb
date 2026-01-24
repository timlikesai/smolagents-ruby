require "spec_helper"

RSpec.describe Smolagents::Types::GoalConfig do
  describe ".new" do
    it "defaults to enabled and not visible" do
      config = described_class.new

      expect(config.enabled).to be true
      expect(config.visible).to be false
    end

    it "accepts enabled option" do
      config = described_class.new(enabled: false)
      expect(config.enabled).to be false
    end

    it "accepts visible option" do
      config = described_class.new(visible: true)
      expect(config.visible).to be true
    end
  end

  describe ".disabled" do
    it "creates disabled configuration" do
      config = described_class.disabled

      expect(config.enabled).to be false
      expect(config.visible).to be false
    end
  end

  describe ".visible" do
    it "creates enabled configuration with visibility" do
      config = described_class.visible

      expect(config.enabled).to be true
      expect(config.visible).to be true
    end
  end

  describe "immutability" do
    it "is frozen" do
      config = described_class.new
      expect(config.frozen?).to be true
    end
  end
end
