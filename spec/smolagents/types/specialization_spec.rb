RSpec.describe Smolagents::Types::Specialization do
  describe ".create" do
    it "creates specialization with normalized name" do
      spec = described_class.create("researcher")

      expect(spec.name).to eq(:researcher)
    end

    it "converts string name to symbol" do
      spec = described_class.create("helper")

      expect(spec.name).to be_a(Symbol)
    end

    it "creates specialization with normalized tools" do
      spec = described_class.create(:helper, tools: ["search", :web])

      expect(spec.tools).to eq(%i[search web])
      expect(spec.tools).to all(be_a(Symbol))
    end

    it "wraps single tool in array" do
      spec = described_class.create(:helper, tools: :search)

      expect(spec.tools).to eq([:search])
    end

    it "creates specialization with nil instructions" do
      spec = described_class.create(:helper)

      expect(spec.instructions).to be_nil
    end

    it "creates specialization with frozen instructions" do
      spec = described_class.create(:helper, instructions: "Be helpful")

      expect(spec.instructions).to eq("Be helpful")
      expect(spec.instructions).to be_frozen
    end

    it "is frozen" do
      spec = described_class.create(:helper)

      expect(spec).to be_frozen
    end
  end

  describe "attributes" do
    it "has name, tools, and instructions" do
      spec = described_class.create(
        :researcher,
        tools: %i[web_search visit_webpage],
        instructions: "Research specialist"
      )

      expect(spec.name).to eq(:researcher)
      expect(spec.tools).to eq(%i[web_search visit_webpage])
      expect(spec.instructions).to eq("Research specialist")
    end
  end

  describe "with empty tools" do
    it "defaults to empty array" do
      spec = described_class.create(:simple)

      expect(spec.tools).to eq([])
    end
  end

  describe "pattern matching" do
    it "matches on name" do
      spec = described_class.create(:researcher)

      matched = case spec
                in name: :researcher
                  "researcher"
                else
                  "other"
                end

      expect(matched).to eq("researcher")
    end

    it "matches on tools" do
      spec = described_class.create(:helper, tools: [:search])

      matched = case spec
                in tools: [:search]
                  "has search"
                else
                  "no search"
                end

      expect(matched).to eq("has search")
    end
  end

  describe "immutability" do
    it "creates frozen instances" do
      spec = described_class.create(:helper, tools: [:search])

      expect(spec).to be_frozen
    end

    it "tools array is accessible" do
      spec = described_class.create(:helper, tools: %i[search web])

      expect(spec.tools).to eq(%i[search web])
    end
  end
end
