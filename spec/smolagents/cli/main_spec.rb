require "thor"
require "smolagents/cli/main"

RSpec.describe Smolagents::CLI::Main do
  it "inherits from Thor" do
    expect(described_class.superclass).to eq(Thor)
  end

  it "includes ModelBuilder" do
    expect(described_class.included_modules).to include(Smolagents::CLI::ModelBuilder)
  end

  it "includes Commands" do
    expect(described_class.included_modules).to include(Smolagents::CLI::Commands)
  end

  it "has PROVIDERS constant available via ModelBuilder" do
    expect(Smolagents::CLI::ModelBuilder::PROVIDERS).to be_a(Hash)
  end
end
