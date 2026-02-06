require "spec_helper"

RSpec.describe Smolagents::Config::Configuration::Environment do
  describe "ENV_MAPPINGS" do
    it "defines mapping for search_provider" do
      mapping = described_class::ENV_MAPPINGS[:search_provider]

      expect(mapping[:env]).to eq("SMOLAGENTS_SEARCH_PROVIDER")
      expect(mapping[:transform]).to eq(:to_sym)
    end
  end

  describe "#load_from_environment!" do
    let(:config) { Smolagents::Config::Configuration.new }

    around do |example|
      original_search = ENV.fetch("SMOLAGENTS_SEARCH_PROVIDER", nil)
      example.run
    ensure
      ENV["SMOLAGENTS_SEARCH_PROVIDER"] = original_search
    end

    it "loads search_provider from environment" do
      ENV["SMOLAGENTS_SEARCH_PROVIDER"] = "google"

      config.reset!

      expect(config.search_provider).to eq(:google)
    end

    it "skips empty environment values" do
      ENV["SMOLAGENTS_SEARCH_PROVIDER"] = ""

      config.reset!

      expect(config.search_provider).to eq(:duckduckgo) # default
    end

    it "skips nil environment values" do
      ENV.delete("SMOLAGENTS_SEARCH_PROVIDER")

      config.reset!

      expect(config.search_provider).to eq(:duckduckgo) # default
    end
  end
end
