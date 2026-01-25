require "spec_helper"

RSpec.describe Smolagents::Builders::AgentToolsConcern do
  include_context "with mocked tools"
  include_context "with mocked model"

  let(:builder_class) { Smolagents::Builders::AgentBuilder }
  let(:builder) { builder_class.create }

  describe "#tools" do
    context "with symbol tool names" do
      it "adds tool names to configuration" do
        result = builder.tools(:google_search, :visit_webpage)

        expect(result.config[:tool_names]).to eq(%i[google_search visit_webpage])
      end

      it "converts string names to symbols" do
        result = builder.tools("google_search", "visit_webpage")

        expect(result.config[:tool_names]).to eq(%i[google_search visit_webpage])
      end

      it "returns a new builder instance (immutability)" do
        result = builder.tools(:google_search)

        expect(result).not_to equal(builder)
        expect(result).to be_a(builder_class)
      end

      it "does not mutate original builder" do
        original_tools = builder.config[:tool_names].dup
        builder.tools(:google_search)

        expect(builder.config[:tool_names]).to eq(original_tools)
      end
    end

    context "with tool instances" do
      it "adds tool instances to configuration" do
        result = builder.tools(mock_search_tool)

        expect(result.config[:tool_instances]).to eq([mock_search_tool])
      end

      it "separates instances from names" do
        result = builder.tools(:google_search, mock_search_tool)

        expect(result.config[:tool_names]).to eq([:google_search])
        expect(result.config[:tool_instances]).to eq([mock_search_tool])
      end
    end

    context "with toolkit names" do
      it "expands :search toolkit" do
        result = builder.tools(:search)

        expect(result.config[:tool_names]).to include(:duckduckgo_search)
        expect(result.config[:tool_names]).to include(:wikipedia_search)
      end

      it "expands :web toolkit" do
        result = builder.tools(:web)

        expect(result.config[:tool_names]).to include(:visit_webpage)
      end

      it "expands :data toolkit" do
        result = builder.tools(:data)

        expect(result.config[:tool_names]).to include(:ruby_interpreter)
      end

      it "expands :research toolkit (combines search and web)" do
        result = builder.tools(:research)

        expect(result.config[:tool_names]).to include(:duckduckgo_search)
        expect(result.config[:tool_names]).to include(:wikipedia_search)
        expect(result.config[:tool_names]).to include(:visit_webpage)
      end

      it "handles mixed toolkits and individual tools" do
        result = builder.tools(:search, :visit_webpage)

        expect(result.config[:tool_names]).to include(:duckduckgo_search)
        expect(result.config[:tool_names]).to include(:wikipedia_search)
        expect(result.config[:tool_names]).to include(:visit_webpage)
      end
    end

    context "with multiple calls (accumulation)" do
      it "accumulates tool names across calls" do
        result = builder
                 .tools(:google_search)
                 .tools(:visit_webpage)

        expect(result.config[:tool_names]).to eq(%i[google_search visit_webpage])
      end

      it "accumulates tool instances across calls" do
        tool1 = mock_search_tool
        tool2 = mock_final_answer_tool

        result = builder
                 .tools(tool1)
                 .tools(tool2)

        expect(result.config[:tool_instances]).to eq([tool1, tool2])
      end

      it "accumulates mixed tools across calls" do
        result = builder
                 .tools(:google_search)
                 .tools(mock_search_tool)
                 .tools(:visit_webpage)

        expect(result.config[:tool_names]).to eq(%i[google_search visit_webpage])
        expect(result.config[:tool_instances]).to eq([mock_search_tool])
      end
    end

    context "with array argument" do
      it "flattens nested arrays" do
        result = builder.tools(%i[google_search visit_webpage])

        expect(result.config[:tool_names]).to eq(%i[google_search visit_webpage])
      end
    end

    context "when builder is frozen" do
      it "raises FrozenError" do
        frozen = builder.freeze!

        expect { frozen.tools(:google_search) }
          .to raise_error(FrozenError)
      end
    end
  end
end
