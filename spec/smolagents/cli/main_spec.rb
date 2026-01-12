# frozen_string_literal: true

require "thor"
require "smolagents/cli/main"

# Note: We test CLI::Main indirectly because "run" is a Thor reserved word
# that causes issues when the class is loaded in certain contexts.
# The actual command functionality is tested via commands_spec.rb

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
