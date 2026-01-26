RSpec.describe Smolagents::Personas do
  describe "persona methods" do
    it "defines researcher persona" do
      expect(described_class.researcher).to include("research specialist")
      expect(described_class.researcher).to include("Search for relevant")
    end

    it "defines fact_checker persona" do
      expect(described_class.fact_checker).to include("fact-checking specialist")
      expect(described_class.fact_checker).to include("confidence level")
    end

    it "defines analyst persona" do
      expect(described_class.analyst).to include("data analysis specialist")
      expect(described_class.analyst).to include("statistical methods")
    end

    it "defines calculator persona" do
      expect(described_class.calculator).to include("calculator")
      expect(described_class.calculator).to include("numeric result")
    end

    it "defines scraper persona" do
      expect(described_class.scraper).to include("web scraping specialist")
      expect(described_class.scraper).to include("Extract the requested")
    end
  end

  describe ".names" do
    it "returns all persona names as symbols" do
      names = described_class.names
      expect(names).to include(:researcher, :fact_checker, :analyst, :calculator, :scraper)
      expect(names).to all(be_a(Symbol))
    end
  end

  describe ".get" do
    it "returns persona by name" do
      expect(described_class.get(:researcher)).to eq(described_class.researcher)
      expect(described_class.get(:analyst)).to eq(described_class.analyst)
    end

    it "returns nil for unknown persona" do
      expect(described_class.get(:nonexistent)).to be_nil
    end
  end

  describe "usage with AgentBuilder" do
    it "can be applied with .as method" do
      builder = Smolagents.agent.as(:researcher)
      expect(builder.configuration[:custom_instructions]).to include("research specialist")
    end

    it "can be applied with .persona method (alias for .as)" do
      builder = Smolagents.agent.persona(:researcher)
      expect(builder.configuration[:custom_instructions]).to include("research specialist")
    end

    it ".persona and .as produce identical results" do
      as_builder = Smolagents.agent.as(:analyst)
      persona_builder = Smolagents.agent.persona(:analyst)

      expect(persona_builder.configuration[:custom_instructions])
        .to eq(as_builder.configuration[:custom_instructions])
    end

    it "can be applied directly with .instructions" do
      builder = Smolagents.agent.instructions(described_class.analyst)
      expect(builder.configuration[:custom_instructions]).to include("data analysis")
    end

    it "raises for unknown persona" do
      expect { Smolagents.agent.as(:nonexistent) }.to raise_error(ArgumentError, /Unknown persona/)
    end

    it "raises for unknown persona with .persona alias" do
      expect { Smolagents.agent.persona(:nonexistent) }.to raise_error(ArgumentError, /Unknown persona/)
    end
  end
end
