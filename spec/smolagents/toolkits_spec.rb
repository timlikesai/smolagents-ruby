RSpec.describe Smolagents::Toolkits do
  describe "toolkit methods" do
    it "defines search toolkit with search tools" do
      expect(described_class.search).to contain_exactly(:duckduckgo_search, :wikipedia_search)
    end

    it "defines web toolkit with browsing tools" do
      expect(described_class.web).to eq([:visit_webpage])
    end

    it "defines data toolkit with data tools" do
      expect(described_class.data).to eq([:ruby_interpreter])
    end

    it "defines research toolkit combining search and web" do
      expect(described_class.research).to include(*described_class.search)
      expect(described_class.research).to include(*described_class.web)
    end
  end

  describe ".names" do
    it "returns all toolkit names as symbols" do
      names = described_class.names
      expect(names).to include(:search, :web, :data, :research)
      expect(names).to all(be_a(Symbol))
    end
  end

  describe ".get" do
    it "returns toolkit by name" do
      expect(described_class.get(:search)).to eq(described_class.search)
      expect(described_class.get(:web)).to eq(described_class.web)
    end

    it "returns nil for unknown toolkit" do
      expect(described_class.get(:nonexistent)).to be_nil
    end
  end

  describe ".toolkit?" do
    it "returns true for known toolkits" do
      expect(described_class.toolkit?(:search)).to be true
      expect(described_class.toolkit?(:web)).to be true
    end

    it "returns false for unknown names" do
      expect(described_class.toolkit?(:nonexistent)).to be false
      expect(described_class.toolkit?(:duckduckgo_search)).to be false
    end
  end

  describe "automatic expansion in AgentBuilder" do
    it "expands toolkit names in .tools()" do
      builder = Smolagents.agent.tools(:search)
      expect(builder.configuration[:tool_names]).to include(:duckduckgo_search, :wikipedia_search)
    end

    it "combines multiple toolkits" do
      builder = Smolagents.agent.tools(:search, :web)
      expect(builder.configuration[:tool_names]).to include(
        :duckduckgo_search, :wikipedia_search, :visit_webpage
      )
    end

    it "mixes toolkits with individual tools" do
      builder = Smolagents.agent.tools(:search, :final_answer)
      tools = builder.configuration[:tool_names]
      expect(tools).to include(:duckduckgo_search, :wikipedia_search, :final_answer)
    end
  end
end
