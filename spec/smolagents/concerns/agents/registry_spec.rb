require "spec_helper"

RSpec.describe Smolagents::Concerns::Agents::Registry do
  describe "CONCERNS" do
    it "contains metadata for all agent concerns" do
      expect(described_class::CONCERNS).to be_a(Hash)
      expect(described_class::CONCERNS.keys).to include(:react_loop, :planning, :self_refine)
    end

    it "each concern has required metadata keys" do
      described_class::CONCERNS.each do |name, meta|
        expect(meta).to have_key(:requires), "#{name} missing :requires"
        expect(meta).to have_key(:notes), "#{name} missing :notes"
      end
    end
  end

  describe ".standalone" do
    it "returns concerns with no dependencies" do
      standalone = described_class.standalone
      expect(standalone).to include(:react_loop, :self_refine, :reflection_memory)
      expect(standalone).not_to include(:react_loop_control, :evaluation)
    end
  end

  describe ".dependent" do
    it "returns concerns that require other concerns" do
      dependent = described_class.dependent
      expect(dependent).to include(:react_loop_control, :react_loop_repetition, :evaluation, :planning)
      expect(dependent).not_to include(:react_loop, :self_refine)
    end
  end

  describe ".[]" do
    it "returns metadata for a known concern" do
      meta = described_class[:react_loop]
      expect(meta[:path]).to eq("react_loop")
      expect(meta[:auto_includes]).to eq(%i[core execution])
    end

    it "returns nil for unknown concern" do
      expect(described_class[:unknown_concern]).to be_nil
    end
  end
end
