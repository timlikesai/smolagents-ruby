require "spec_helper"

RSpec.describe Smolagents::Http::UserAgent::Builder do
  describe ".build" do
    context "with minimal configuration" do
      it "builds User-Agent with library version and Ruby version" do
        user_agent = Smolagents::Http::UserAgent.new

        result = described_class.build(user_agent)

        expect(result).to include("Smolagents/#{Smolagents::VERSION}")
        expect(result).to include("Ruby/#{RUBY_VERSION}")
        expect(result).to include("(+https://github.com/timlikesai/smolagents-ruby; bot)")
      end
    end

    context "with agent context" do
      it "includes agent name and version" do
        user_agent = Smolagents::Http::UserAgent.new(
          agent_name: "ResearchBot",
          agent_version: "2.0"
        )

        result = described_class.build(user_agent)

        expect(result).to start_with("ResearchBot/2.0")
        expect(result).to include("Smolagents/")
      end
    end

    context "with tool context" do
      it "includes tool name" do
        user_agent = Smolagents::Http::UserAgent.new(tool_name: "VisitWebpage")

        result = described_class.build(user_agent)

        expect(result).to include("Tool:VisitWebpage")
      end
    end

    context "with model context" do
      it "includes sanitized model ID" do
        user_agent = Smolagents::Http::UserAgent.new(model_id: "gpt-4-turbo")

        result = described_class.build(user_agent)

        expect(result).to include("Model:gpt-4-turbo")
      end
    end

    context "with full configuration" do
      it "builds complete User-Agent string in correct order" do
        user_agent = Smolagents::Http::UserAgent.new(
          agent_name: "MyAgent",
          agent_version: "1.0",
          tool_name: "Search",
          model_id: "llama-3",
          contact_url: "https://example.com/bot"
        )

        result = described_class.build(user_agent)

        # Verify order: agent, library, tool, model, ruby, contact
        components = result.split
        expect(components[0]).to eq("MyAgent/1.0")
        expect(components[1]).to start_with("Smolagents/")
        expect(components[2]).to eq("Tool:Search")
        expect(components[3]).to eq("Model:llama-3")
        expect(components[4]).to start_with("Ruby/")
        expect(components[5]).to include("+https://example.com/bot")
      end
    end

    context "conditional components" do
      it "omits agent component when agent_name is nil" do
        user_agent = Smolagents::Http::UserAgent.new(agent_name: nil)

        result = described_class.build(user_agent)

        expect(result).not_to include("/nil")
        expect(result).to start_with("Smolagents/")
      end

      it "omits tool component when tool_name is nil" do
        user_agent = Smolagents::Http::UserAgent.new(tool_name: nil)

        result = described_class.build(user_agent)

        expect(result).not_to include("Tool:")
      end

      it "omits model component when model_id is nil" do
        user_agent = Smolagents::Http::UserAgent.new(model_id: nil)

        result = described_class.build(user_agent)

        expect(result).not_to include("Model:")
      end
    end
  end

  describe "COMPONENTS" do
    it "defines component configuration as frozen array" do
      expect(described_class::COMPONENTS).to be_frozen
      expect(described_class::COMPONENTS).to be_an(Array)
    end

    it "contains expected component count" do
      expect(described_class::COMPONENTS.size).to eq(6)
    end

    it "includes required keys for each component" do
      described_class::COMPONENTS.each do |component|
        expect(component).to have_key(:prefix)
        expect(component).to have_key(:method)
        expect(component).to have_key(:suffix)
        expect(component).to have_key(:conditional)
      end
    end
  end
end
