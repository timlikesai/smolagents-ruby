RSpec.describe Smolagents::Specializations do
  describe ".register" do
    after { described_class.instance_variable_get(:@registry).delete(:test_spec) }

    it "registers a new specialization" do
      described_class.register(:test_spec, tools: [:my_tool], instructions: "Do stuff")
      spec = described_class.get(:test_spec)

      expect(spec).to be_a(Smolagents::Types::Specialization)
      expect(spec.name).to eq(:test_spec)
      expect(spec.tools).to eq([:my_tool])
      expect(spec.instructions).to eq("Do stuff")
    end

    it "registers specialization with requires" do
      described_class.register(:test_spec, requires: :code)
      spec = described_class.get(:test_spec)

      expect(spec.requires).to eq(:code)
      expect(spec.needs_code?).to be true
    end
  end

  describe ".get" do
    it "returns registered specialization" do
      spec = described_class.get(:researcher)

      expect(spec).to be_a(Smolagents::Types::Specialization)
      expect(spec.name).to eq(:researcher)
    end

    it "returns nil for unknown specialization" do
      expect(described_class.get(:nonexistent)).to be_nil
    end
  end

  describe ".names" do
    it "returns all registered specialization names" do
      names = described_class.names

      expect(names).to include(:code, :researcher, :data_analyst, :fact_checker)
    end
  end

  describe ".all" do
    it "returns all registered specializations" do
      all = described_class.all

      expect(all).to all(be_a(Smolagents::Types::Specialization))
      expect(all.map(&:name)).to include(:code, :researcher)
    end
  end

  describe "built-in specializations" do
    describe ":code" do
      it "is a mode marker with no tools" do
        spec = described_class.get(:code)

        expect(spec.tools).to be_empty
        expect(spec.instructions).to be_nil
      end
    end

    describe ":researcher" do
      it "includes search tools" do
        spec = described_class.get(:researcher)

        expect(spec.tools).to include(:duckduckgo_search, :visit_webpage, :wikipedia_search)
        expect(spec.instructions).to include("research")
      end
    end

    describe ":data_analyst" do
      it "requires code execution" do
        spec = described_class.get(:data_analyst)

        expect(spec.needs_code?).to be true
        expect(spec.tools).to include(:ruby_interpreter)
      end
    end

    describe ":fact_checker" do
      it "includes verification tools" do
        spec = described_class.get(:fact_checker)

        expect(spec.tools).to include(:duckduckgo_search, :wikipedia_search)
        expect(spec.instructions).to include("fact")
      end
    end
  end

  describe "relationship to Toolkits and Personas" do
    it "specializations are convenience bundles of atoms" do
      # Researcher specialization should be equivalent to:
      # .tools(:research).as(:researcher)
      spec = described_class.get(:researcher)

      # Tools come from Toolkits
      expect(spec.tools).to include(*Smolagents::Toolkits.search)
      expect(spec.tools).to include(*Smolagents::Toolkits.web)

      # Instructions match Personas
      expect(spec.instructions).to include("research specialist")
    end

    it "users can build equivalent agents with atoms or specializations" do
      # Using specialization
      spec_builder = Smolagents.agent.with(:researcher)

      # Using atoms (toolkit name auto-expands)
      atom_builder = Smolagents.agent
                               .tools(:research)
                               .as(:researcher)

      # Both should have the same tools (order may differ)
      spec_tools = spec_builder.configuration[:tool_names].sort
      atom_tools = atom_builder.configuration[:tool_names].sort
      expect(spec_tools).to eq(atom_tools)

      # Both should have similar instructions
      expect(spec_builder.configuration[:custom_instructions])
        .to include("research specialist")
      expect(atom_builder.configuration[:custom_instructions])
        .to include("research specialist")
    end
  end
end
