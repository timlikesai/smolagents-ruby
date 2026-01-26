require "spec_helper"

RSpec.describe Smolagents::Builders::SpecializationConcern do
  include_context "with mocked tools"
  include_context "with mocked model"

  let(:builder_class) { Smolagents::Builders::AgentBuilder }
  let(:builder) { builder_class.create }

  describe "#as" do
    it "applies persona instructions" do
      result = builder.as(:researcher)

      expect(result.config[:custom_instructions]).to include("research specialist")
    end

    it "returns a new builder instance (immutability)" do
      result = builder.as(:researcher)

      expect(result).not_to equal(builder)
      expect(result).to be_a(builder_class)
    end

    it "does not mutate original builder" do
      original_instructions = builder.config[:custom_instructions]
      builder.as(:researcher)

      expect(builder.config[:custom_instructions]).to eq(original_instructions)
    end

    it "raises error for unknown persona" do
      expect { builder.as(:unknown_persona) }
        .to raise_error(ArgumentError, /Unknown persona: unknown_persona/)
    end

    it "includes available personas in error message" do
      expect { builder.as(:nonexistent) }
        .to raise_error(ArgumentError, /researcher/)
    end

    context "with supported personas" do
      it "applies :researcher persona" do
        result = builder.as(:researcher)

        expect(result.config[:custom_instructions]).to include("research specialist")
      end

      it "applies :fact_checker persona" do
        result = builder.as(:fact_checker)

        expect(result.config[:custom_instructions]).to include("fact-checking specialist")
      end

      it "applies :analyst persona" do
        result = builder.as(:analyst)

        expect(result.config[:custom_instructions]).to include("data analysis")
      end

      it "applies :calculator persona" do
        result = builder.as(:calculator)

        expect(result.config[:custom_instructions]).to include("calculator")
      end

      it "applies :scraper persona" do
        result = builder.as(:scraper)

        expect(result.config[:custom_instructions]).to include("scraping specialist")
      end
    end

    context "when builder is frozen" do
      it "raises FrozenError" do
        frozen = builder.freeze!

        expect { frozen.as(:researcher) }
          .to raise_error(FrozenError)
      end
    end
  end

  describe "#persona" do
    it "is an alias for #as" do
      result = builder.persona(:researcher)

      expect(result.config[:custom_instructions]).to include("research specialist")
    end

    it "returns a new builder instance (immutability)" do
      result = builder.persona(:researcher)

      expect(result).not_to equal(builder)
    end
  end

  describe "#with" do
    it "applies specialization tools and instructions" do
      result = builder.with(:researcher)

      expect(result.config[:tool_names]).not_to be_empty
      expect(result.config[:custom_instructions]).not_to be_nil
    end

    it "returns a new builder instance (immutability)" do
      result = builder.with(:researcher)

      expect(result).not_to equal(builder)
      expect(result).to be_a(builder_class)
    end

    it "does not mutate original builder" do
      original_tools = builder.config[:tool_names].dup
      builder.with(:researcher)

      expect(builder.config[:tool_names]).to eq(original_tools)
    end

    it "returns self when passed empty arguments" do
      result = builder.with

      expect(result).to equal(builder)
    end

    it "returns self when passed empty array" do
      result = builder.with([])

      expect(result).to equal(builder)
    end

    it "ignores :code specialization (all agents write code)" do
      result = builder.with(:code)

      # :code is accepted but ignored since all agents write code
      expect(result).to equal(builder)
    end

    it "processes other specializations when :code is mixed in" do
      result = builder.with(:code, :researcher)

      # :code is ignored, but :researcher is applied
      expect(result.config[:tool_names]).not_to be_empty
    end

    it "raises error for unknown specialization" do
      expect { builder.with(:unknown_specialization) }
        .to raise_error(ArgumentError, /Unknown specialization: unknown_specialization/)
    end

    it "includes available specializations in error message" do
      expect { builder.with(:nonexistent) }
        .to raise_error(ArgumentError, /researcher/)
    end

    it "accepts multiple specializations" do
      result = builder.with(:researcher, :fact_checker)

      expect(result.config[:custom_instructions]).to include("research")
    end

    it "merges tools from multiple specializations" do
      initial_tools = builder.config[:tool_names].dup
      result = builder.with(:researcher)

      expect(result.config[:tool_names].size).to be >= initial_tools.size
    end

    it "deduplicates tools when adding specializations" do
      # Add some tools, then add a specialization that includes same tools
      result = builder.tools(:google_search).with(:researcher)

      # Tools should be unique
      expect(result.config[:tool_names]).to eq(result.config[:tool_names].uniq)
    end

    it "merges instructions with existing instructions" do
      result = builder.instructions("Initial instruction").with(:researcher)

      instructions = result.config[:custom_instructions]
      expect(instructions).to include("Initial instruction")
      expect(instructions).to include("research")
    end

    context "when builder is frozen" do
      it "raises FrozenError" do
        frozen = builder.freeze!

        expect { frozen.with(:researcher) }
          .to raise_error(FrozenError)
      end
    end
  end

  describe "chaining" do
    it "supports chaining with other builder methods" do
      result = builder
               .as(:researcher)
               .tools(:google_search)
               .max_steps(10)

      expect(result.config[:custom_instructions]).to include("research")
      expect(result.config[:tool_names]).to include(:google_search)
      expect(result.config[:max_steps]).to eq(10)
    end

    it "supports multiple persona/specialization calls (last wins for instructions)" do
      result = builder
               .as(:researcher)
               .as(:analyst)

      # Instructions are appended, not replaced
      expect(result.config[:custom_instructions]).to include("data analysis")
    end

    it "accumulates tools across specializations" do
      result = builder.with(:researcher)

      expect(result.config[:tool_names]).not_to be_empty
    end
  end

  describe "building with specialization" do
    it "creates a working agent with persona" do
      agent = builder
              .model { mock_model }
              .as(:researcher)
              .tools(mock_search_tool)
              .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "creates a working agent with specialization" do
      agent = builder
              .model { mock_model }
              .with(:researcher)
              .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end
end
