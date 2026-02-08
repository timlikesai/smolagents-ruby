RSpec.describe Smolagents::Utilities::Prompts::Agent do
  describe ".generate" do
    let(:tool) do
      instance_double(
        Smolagents::Tool,
        name: "search",
        description: "Search the web",
        inputs: { query: { type: "string", description: "Search query" } },
        output_type: "string"
      )
    end

    it "returns a string prompt" do
      result = described_class.generate(tools: [])

      expect(result).to be_a(String)
      expect(result).not_to be_empty
    end

    it "includes INTRO section with Ruby 4.0 identity" do
      result = described_class.generate(tools: [])

      expect(result).to include("You are a Ruby 4.0 agent")
    end

    it "includes CAPABILITIES section" do
      result = described_class.generate(tools: [])

      expect(result).to include("You CAN:")
      expect(result).to include("You CANNOT:")
    end

    it "includes tool descriptions when tools provided" do
      result = described_class.generate(tools: [tool])

      expect(result).to include("search")
      expect(result).to include("Search the web")
    end

    it "uses AVAILABLE METHODS header for tools" do
      result = described_class.generate(tools: [tool])

      expect(result).to include("AVAILABLE METHODS:")
    end

    it "includes EXAMPLE section" do
      result = described_class.generate(tools: [])

      expect(result).to include("EXAMPLE:")
    end

    it "includes RUBY4_PATTERNS section" do
      result = described_class.generate(tools: [])

      expect(result).to include("RUBY 4.0 PATTERNS")
    end

    it "includes SECURITY section" do
      result = described_class.generate(tools: [])

      expect(result).to include("SECURITY:")
    end

    it "includes HELPERS section" do
      result = described_class.generate(tools: [])

      expect(result).to include("DEBUG HELPERS")
    end

    it "includes custom instructions when provided" do
      result = described_class.generate(tools: [], custom: "Be very concise")

      expect(result).to include("Be very concise")
    end

    it "omits nil sections" do
      result = described_class.generate(tools: [], team: nil, custom: nil)

      expect(result).not_to include("\n\n\n\n")
    end

    context "with max_tokens budget" do
      it "always includes essential P1 sections" do
        result = described_class.generate(tools: [], max_tokens: 5000)

        expect(result).to include("Ruby 4.0 agent")
        expect(result).to include("You CAN:")
      end

      it "includes P2 sections when budget allows" do
        result = described_class.generate(tools: [], max_tokens: 5000)

        expect(result).to include("EXAMPLE:")
        expect(result).to include("SECURITY:")
      end

      it "drops P3 sections when budget is tight" do
        full = described_class.generate(tools: [tool])
        full_tokens = full.length / 4

        # Subtract enough to exclude HELPERS (~20 tokens) but keep P2
        tight_result = described_class.generate(tools: [tool], max_tokens: full_tokens - 5)

        expect(tight_result).to include("EXAMPLE:")
        expect(tight_result).not_to include("DEBUG HELPERS")
      end

      it "drops P2 and P3 sections when budget is very tight" do
        p1_only = described_class.generate(tools: [], max_tokens: 1)

        expect(p1_only).to include("Ruby 4.0 agent")
        expect(p1_only).not_to include("EXAMPLE:")
        expect(p1_only).not_to include("DEBUG HELPERS")
      end

      it "returns full prompt when budget is generous" do
        full = described_class.generate(tools: [tool])
        budgeted = described_class.generate(tools: [tool], max_tokens: 100_000)

        expect(budgeted).to eq(full)
      end
    end
  end
end
