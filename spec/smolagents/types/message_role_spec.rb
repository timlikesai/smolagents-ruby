# frozen_string_literal: true

RSpec.describe Smolagents::MessageRole do
  describe ".all" do
    it "returns all valid roles" do
      expect(described_class.all).to contain_exactly(
        :system, :user, :assistant, :tool_call, :tool_response
      )
    end
  end

  describe ".valid?" do
    it "returns true for valid roles" do
      expect(described_class.valid?(:system)).to be true
      expect(described_class.valid?(:user)).to be true
      expect(described_class.valid?(:assistant)).to be true
    end

    it "returns false for invalid roles" do
      expect(described_class.valid?(:invalid)).to be false
      expect(described_class.valid?(:foo)).to be false
    end
  end
end
