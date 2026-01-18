RSpec.describe Smolagents::Interactive::Help do
  before { Smolagents::Interactive::Colors.enabled = true }
  after { Smolagents::Interactive::Colors.enabled = nil }

  describe "TOPICS" do
    it "defines available help topics" do
      expect(described_class::TOPICS).to eq(%i[models tools agents discovery builder])
    end

    it "is frozen" do
      expect(described_class::TOPICS).to be_frozen
    end
  end

  describe ".show" do
    it "shows general help when no topic given" do
      expect { described_class.show }.to output(/Smolagents Help/).to_stdout
    end

    it "shows general help for nil topic" do
      expect { described_class.show(nil) }.to output(/Smolagents Help/).to_stdout
    end

    it "shows models help for :models topic" do
      expect { described_class.show(:models) }.to output(/Model Configuration/).to_stdout
    end

    it "shows tools help for :tools topic" do
      expect { described_class.show(:tools) }.to output(/Working with Tools/).to_stdout
    end

    it "shows agents help for :agents topic" do
      expect { described_class.show(:agents) }.to output(/Agent Patterns/).to_stdout
    end

    it "shows discovery help for :discovery topic" do
      expect { described_class.show(:discovery) }.to output(/Model Discovery/).to_stdout
    end

    it "shows builder help for :builder topic" do
      expect { described_class.show(:builder) }.to output(/Builder Methods/).to_stdout
    end

    it "shows unknown topic message for invalid topic" do
      expect { described_class.show(:invalid) }.to output(/Unknown topic: invalid/).to_stdout
    end

    it "converts string topic to symbol" do
      expect { described_class.show("models") }.to output(/Model Configuration/).to_stdout
    end
  end

  describe ".show_general" do
    it "outputs help header" do
      expect { described_class.show_general }.to output(/Smolagents Help/).to_stdout
    end

    it "lists available commands" do
      output = capture_stdout { described_class.show_general }
      expect(output).to include("Smolagents.models")
      expect(output).to include("Smolagents.help :models")
      expect(output).to include("Smolagents.help :tools")
      expect(output).to include("Smolagents.help :agents")
    end

    it "includes quick start section" do
      expect { described_class.show_general }.to output(/Quick Start/).to_stdout
    end

    it "includes quick start code example" do
      output = capture_stdout { described_class.show_general }
      expect(output).to include("Smolagents.agent")
      expect(output).to include(".tools(:search)")
    end
  end

  describe ".show_models" do
    it "outputs model configuration header" do
      expect { described_class.show_models }.to output(/Model Configuration/).to_stdout
    end

    it "includes local servers section" do
      expect { described_class.show_models }.to output(/Local Servers/).to_stdout
    end

    it "includes cloud providers section" do
      expect { described_class.show_models }.to output(/Cloud Providers/).to_stdout
    end

    it "shows LM Studio example" do
      output = capture_stdout { described_class.show_models }
      expect(output).to include("lm_studio")
    end

    it "shows Ollama example" do
      output = capture_stdout { described_class.show_models }
      expect(output).to include("ollama")
    end

    it "shows OpenRouter example" do
      output = capture_stdout { described_class.show_models }
      expect(output).to include("openrouter")
    end
  end

  describe ".show_tools" do
    it "outputs tools header" do
      expect { described_class.show_tools }.to output(/Working with Tools/).to_stdout
    end

    it "includes built-in toolkits section" do
      expect { described_class.show_tools }.to output(/Built-in Toolkits/).to_stdout
    end

    it "includes custom tools section" do
      expect { described_class.show_tools }.to output(/Custom Tools/).to_stdout
    end

    it "shows toolkit examples" do
      output = capture_stdout { described_class.show_tools }
      expect(output).to include(".tools(:search)")
      expect(output).to include(".tools(:web)")
      expect(output).to include(".tools(:data)")
    end

    it "shows custom tool class example" do
      output = capture_stdout { described_class.show_tools }
      expect(output).to include("class WeatherTool")
      expect(output).to include("def execute")
    end
  end

  describe ".show_agents" do
    it "outputs agent patterns header" do
      expect { described_class.show_agents }.to output(/Agent Patterns/).to_stdout
    end

    it "includes one-shot execution section" do
      expect { described_class.show_agents }.to output(/One-shot Execution/).to_stdout
    end

    it "includes reusable agent section" do
      expect { described_class.show_agents }.to output(/Reusable Agent/).to_stdout
    end

    it "includes event handlers section" do
      expect { described_class.show_agents }.to output(/Event Handlers/).to_stdout
    end

    it "shows .run example" do
      output = capture_stdout { described_class.show_agents }
      expect(output).to include(".run(")
    end

    it "shows .build example" do
      output = capture_stdout { described_class.show_agents }
      expect(output).to include(".build")
    end

    it "shows event handler example" do
      output = capture_stdout { described_class.show_agents }
      expect(output).to include(".on(:tool_call)")
    end
  end

  describe ".show_discovery" do
    it "outputs discovery header" do
      expect { described_class.show_discovery }.to output(/Model Discovery/).to_stdout
    end

    it "includes scan section" do
      expect { described_class.show_discovery }.to output(/Scan for Models/).to_stdout
    end

    it "includes custom endpoints section" do
      expect { described_class.show_discovery }.to output(/Custom Endpoints/).to_stdout
    end

    it "shows Discovery.scan example" do
      output = capture_stdout { described_class.show_discovery }
      expect(output).to include("Discovery.scan")
    end

    it "shows custom endpoints example" do
      output = capture_stdout { described_class.show_discovery }
      expect(output).to include("custom_endpoints:")
    end
  end

  describe ".show_builder" do
    it "outputs builder header" do
      expect { described_class.show_builder }.to output(/Builder Methods/).to_stdout
    end

    it "includes overview section" do
      expect { described_class.show_builder }.to output(/Overview/).to_stdout
    end

    it "includes .tools section" do
      expect { described_class.show_builder }.to output(/\.tools\(\)/).to_stdout
    end

    it "includes .as section" do
      expect { described_class.show_builder }.to output(/\.as\(\)/).to_stdout
    end

    it "includes .with section" do
      expect { described_class.show_builder }.to output(/\.with\(\)/).to_stdout
    end

    it "includes combining methods section" do
      expect { described_class.show_builder }.to output(/Combining Methods/).to_stdout
    end
  end

  describe ".unknown_topic" do
    it "shows unknown topic message" do
      expect { described_class.unknown_topic(:foo) }.to output(/Unknown topic: foo/).to_stdout
    end

    it "lists available topics" do
      output = capture_stdout { described_class.unknown_topic(:bar) }
      expect(output).to include("models")
      expect(output).to include("tools")
      expect(output).to include("agents")
      expect(output).to include("discovery")
      expect(output).to include("builder")
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end

RSpec.describe Smolagents::Interactive::HelpContent do
  describe "content constants" do
    it "defines QUICK_START" do
      expect(described_class::QUICK_START).to include("Smolagents.agent")
      expect(described_class::QUICK_START).to be_frozen
    end

    it "defines LOCAL_SERVERS_HELP" do
      expect(described_class::LOCAL_SERVERS_HELP).to include("lm_studio")
      expect(described_class::LOCAL_SERVERS_HELP).to include("ollama")
      expect(described_class::LOCAL_SERVERS_HELP).to be_frozen
    end

    it "defines CLOUD_PROVIDERS_HELP" do
      expect(described_class::CLOUD_PROVIDERS_HELP).to include("openrouter")
      expect(described_class::CLOUD_PROVIDERS_HELP).to include("groq")
      expect(described_class::CLOUD_PROVIDERS_HELP).to be_frozen
    end

    it "defines TOOLKITS_HELP" do
      expect(described_class::TOOLKITS_HELP).to include(":search")
      expect(described_class::TOOLKITS_HELP).to include(":web")
      expect(described_class::TOOLKITS_HELP).to be_frozen
    end

    it "defines CUSTOM_TOOLS_HELP" do
      expect(described_class::CUSTOM_TOOLS_HELP).to include("class WeatherTool")
      expect(described_class::CUSTOM_TOOLS_HELP).to be_frozen
    end

    it "defines ONESHOT_HELP" do
      expect(described_class::ONESHOT_HELP).to include(".run(")
      expect(described_class::ONESHOT_HELP).to be_frozen
    end

    it "defines REUSABLE_HELP" do
      expect(described_class::REUSABLE_HELP).to include(".build")
      expect(described_class::REUSABLE_HELP).to be_frozen
    end

    it "defines EVENTS_HELP" do
      expect(described_class::EVENTS_HELP).to include(".on(:tool_call)")
      expect(described_class::EVENTS_HELP).to be_frozen
    end

    it "defines SCAN_HELP" do
      expect(described_class::SCAN_HELP).to include("Discovery.scan")
      expect(described_class::SCAN_HELP).to be_frozen
    end

    it "defines ENDPOINTS_HELP" do
      expect(described_class::ENDPOINTS_HELP).to include("custom_endpoints:")
      expect(described_class::ENDPOINTS_HELP).to be_frozen
    end
  end
end
