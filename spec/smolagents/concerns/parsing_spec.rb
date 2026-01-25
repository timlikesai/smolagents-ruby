require "spec_helper"
require "smolagents/concerns/parsing"

RSpec.describe Smolagents::Concerns::Parsing do
  describe "namespace loader" do
    it "loads Json module" do
      expect(defined?(Smolagents::Concerns::Json)).to eq("constant")
    end

    it "loads Html module" do
      expect(defined?(Smolagents::Concerns::Html)).to eq("constant")
    end

    it "loads Xml module" do
      expect(defined?(Smolagents::Concerns::Xml)).to eq("constant")
    end

    it "loads CritiqueParsing module" do
      expect(defined?(Smolagents::Concerns::CritiqueParsing)).to eq("constant")
    end
  end
end
