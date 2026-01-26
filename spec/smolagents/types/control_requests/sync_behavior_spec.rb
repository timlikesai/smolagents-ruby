require "spec_helper"

RSpec.describe Smolagents::Types::ControlRequests::SyncBehavior do
  describe "constants" do
    it "defines RAISE as :raise" do
      expect(described_class::RAISE).to eq(:raise)
    end

    it "defines DEFAULT as :default" do
      expect(described_class::DEFAULT).to eq(:default)
    end

    it "defines APPROVE as :approve" do
      expect(described_class::APPROVE).to eq(:approve)
    end

    it "defines SKIP as :skip" do
      expect(described_class::SKIP).to eq(:skip)
    end
  end

  describe "usage in request types" do
    describe "UserInput default sync_behavior" do
      it "defaults to DEFAULT" do
        request = Smolagents::Types::ControlRequests::UserInput.create(prompt: "test")
        expect(request.sync_behavior).to eq(described_class::DEFAULT)
      end
    end

    describe "SubAgentQuery default sync_behavior" do
      it "defaults to SKIP" do
        request = Smolagents::Types::ControlRequests::SubAgentQuery.create(
          agent_name: "test",
          query: "?"
        )
        expect(request.sync_behavior).to eq(described_class::SKIP)
      end
    end

    describe "Confirmation sync_behavior" do
      it "is APPROVE when reversible" do
        request = Smolagents::Types::ControlRequests::Confirmation.create(
          action: "test",
          description: "test",
          reversible: true
        )
        expect(request.sync_behavior).to eq(described_class::APPROVE)
      end

      it "is RAISE when not reversible" do
        request = Smolagents::Types::ControlRequests::Confirmation.create(
          action: "test",
          description: "test",
          reversible: false
        )
        expect(request.sync_behavior).to eq(described_class::RAISE)
      end
    end
  end

  describe "pattern matching" do
    # rubocop:disable Style/HashLikeCase -- demonstrating case/when pattern matching
    it "supports case/when matching on behavior" do
      behavior = described_class::RAISE
      result = case behavior
               when :raise then "will raise"
               when :default then "use default"
               when :approve then "auto-approve"
               when :skip then "skip request"
               end
      expect(result).to eq("will raise")
    end
    # rubocop:enable Style/HashLikeCase

    it "can be used in case/in pattern matching" do
      request = Smolagents::Types::ControlRequests::UserInput.create(prompt: "test")
      behavior = case request
                 in { sync_behavior: :default } then :uses_default
                 in { sync_behavior: :skip } then :skips
                 in { sync_behavior: :raise } then :raises
                 in { sync_behavior: :approve } then :approves
                 end
      expect(behavior).to eq(:uses_default)
    end
  end
end
