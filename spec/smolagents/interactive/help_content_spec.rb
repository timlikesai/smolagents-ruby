require "spec_helper"

RSpec.describe Smolagents::Interactive::HelpContent do
  describe "builder method constants" do
    describe "BUILDER_METHODS_HELP" do
      it "explains the three builder methods" do
        content = described_class::BUILDER_METHODS_HELP

        expect(content).to include(".tools")
        expect(content).to include(".as")
        expect(content).to include(".with")
      end

      it "explains the relationship between methods" do
        content = described_class::BUILDER_METHODS_HELP

        expect(content).to include(".with(:researcher) == .tools(:research).as(:researcher)")
      end

      it "is frozen" do
        expect(described_class::BUILDER_METHODS_HELP).to be_frozen
      end
    end

    describe "BUILDER_TOOLS_HELP" do
      it "shows toolkit usage examples" do
        content = described_class::BUILDER_TOOLS_HELP

        expect(content).to include(".tools(:search)")
        expect(content).to include(".tools(:search, :web)")
      end

      it "lists available toolkits" do
        content = described_class::BUILDER_TOOLS_HELP

        expect(content).to include(":search")
        expect(content).to include(":web")
        expect(content).to include(":data")
        expect(content).to include(":research")
      end
    end

    describe "BUILDER_AS_HELP" do
      it "shows persona usage" do
        content = described_class::BUILDER_AS_HELP

        expect(content).to include(".as(:researcher)")
      end

      it "lists available personas" do
        content = described_class::BUILDER_AS_HELP

        expect(content).to include(":researcher")
        expect(content).to include(":fact_checker")
        expect(content).to include(":analyst")
        expect(content).to include(":calculator")
        expect(content).to include(":scraper")
      end
    end

    describe "BUILDER_WITH_HELP" do
      it "shows specialization usage" do
        content = described_class::BUILDER_WITH_HELP

        expect(content).to include(".with(:researcher)")
      end

      it "lists available specializations" do
        content = described_class::BUILDER_WITH_HELP

        expect(content).to include(":researcher")
        expect(content).to include(":fact_checker")
        expect(content).to include(":data_analyst")
        expect(content).to include(":calculator")
        expect(content).to include(":web_scraper")
      end
    end

    describe "BUILDER_COMBINING_HELP" do
      it "shows method chaining example" do
        content = described_class::BUILDER_COMBINING_HELP

        expect(content).to include("Smolagents.agent")
        expect(content).to include(".with(:researcher)")
        expect(content).to include(".tools(:data)")
        expect(content).to include(".instructions")
        expect(content).to include(".build")
      end
    end
  end

  describe "quick start constants" do
    describe "QUICK_START" do
      it "shows complete agent creation example" do
        content = described_class::QUICK_START

        expect(content).to include("Smolagents.agent")
        expect(content).to include(".model")
        expect(content).to include(".tools(:search)")
        expect(content).to include(".run")
      end
    end
  end

  describe "model configuration constants" do
    describe "LOCAL_SERVERS_HELP" do
      it "shows LM Studio configuration" do
        content = described_class::LOCAL_SERVERS_HELP

        expect(content).to include("lm_studio")
        expect(content).to include("1234")
      end

      it "shows Ollama configuration" do
        content = described_class::LOCAL_SERVERS_HELP

        expect(content).to include("ollama")
        expect(content).to include("11434")
      end

      it "shows llama.cpp configuration" do
        content = described_class::LOCAL_SERVERS_HELP

        expect(content).to include("llama_cpp")
        expect(content).to include("8080")
      end
    end

    describe "CLOUD_PROVIDERS_HELP" do
      it "shows OpenRouter configuration" do
        content = described_class::CLOUD_PROVIDERS_HELP

        expect(content).to include("openrouter")
        expect(content).to include("anthropic/claude")
      end

      it "shows Groq configuration" do
        content = described_class::CLOUD_PROVIDERS_HELP

        expect(content).to include("groq")
      end

      it "shows direct OpenAI configuration" do
        content = described_class::CLOUD_PROVIDERS_HELP

        expect(content).to include("OpenAIModel.new")
        expect(content).to include("gpt-4")
      end
    end
  end

  describe "tool constants" do
    describe "TOOLKITS_HELP" do
      it "lists all toolkits" do
        content = described_class::TOOLKITS_HELP

        expect(content).to include(":search")
        expect(content).to include(":web")
        expect(content).to include(":data")
        expect(content).to include(":research")
      end
    end

    describe "CUSTOM_TOOLS_HELP" do
      it "shows tool class definition" do
        content = described_class::CUSTOM_TOOLS_HELP

        expect(content).to include("class WeatherTool < Smolagents::Tool")
        expect(content).to include("self.tool_name")
        expect(content).to include("self.description")
        expect(content).to include("self.inputs")
        expect(content).to include("def execute")
      end
    end
  end

  describe "execution pattern constants" do
    describe "ONESHOT_HELP" do
      it "shows single-use pattern" do
        content = described_class::ONESHOT_HELP

        expect(content).to include("result = Smolagents.agent")
        expect(content).to include(".run")
      end
    end

    describe "REUSABLE_HELP" do
      it "shows reusable agent pattern" do
        content = described_class::REUSABLE_HELP

        expect(content).to include("agent = Smolagents.agent")
        expect(content).to include(".build")
        expect(content).to include('agent.run("Task 1")')
        expect(content).to include('agent.run("Task 2")')
      end
    end

    describe "EVENTS_HELP" do
      it "shows event handling" do
        content = described_class::EVENTS_HELP

        expect(content).to include(".on(:tool_call)")
        expect(content).to include(".on(:step_complete)")
      end
    end
  end

  describe "discovery constants" do
    describe "SCAN_HELP" do
      it "shows discovery scan usage" do
        content = described_class::SCAN_HELP

        expect(content).to include("Discovery.scan")
        expect(content).to include("summary")
        expect(content).to include("code_examples")
      end
    end

    describe "ENDPOINTS_HELP" do
      it "shows custom endpoint configuration" do
        content = described_class::ENDPOINTS_HELP

        expect(content).to include("custom_endpoints")
        expect(content).to include("provider")
        expect(content).to include("host")
        expect(content).to include("port")
        expect(content).to include("tls")
      end
    end
  end

  describe "constant freezing" do
    it "freezes all string constants" do
      constants = described_class.constants.map { |c| described_class.const_get(c) }
      string_constants = constants.select { |c| c.is_a?(String) }

      string_constants.each do |constant|
        expect(constant).to be_frozen
      end
    end
  end
end
