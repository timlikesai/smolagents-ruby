require "smolagents"

RSpec.describe Smolagents::Http::UserAgent do
  describe "initialization" do
    it "creates user agent with default values" do
      ua = described_class.new

      expect(ua.agent_name).to be_nil
      expect(ua.agent_version).to be_nil
      expect(ua.tool_name).to be_nil
      expect(ua.model_id).to be_nil
      expect(ua.contact_url).to eq(described_class::DEFAULT_CONTACT_URL)
    end

    it "accepts all optional parameters" do
      ua = described_class.new(
        agent_name: "TestAgent",
        agent_version: "1.0",
        tool_name: "SearchTool",
        model_id: "gpt-4",
        contact_url: "https://custom.url"
      )

      expect(ua.agent_name).to eq("TestAgent")
      expect(ua.agent_version).to eq("1.0")
      expect(ua.tool_name).to eq("SearchTool")
      expect(ua.model_id).to eq("gpt-4")
      expect(ua.contact_url).to eq("https://custom.url")
    end
  end

  describe "#to_s" do
    it "generates minimal User-Agent without optional fields" do
      ua = described_class.new

      result = ua.to_s

      expect(result).to eq(
        "Smolagents/#{Smolagents::VERSION} Ruby/#{RUBY_VERSION} " \
        "(+#{described_class::DEFAULT_CONTACT_URL}; bot)"
      )
    end

    it "always includes Smolagents version" do
      ua = described_class.new

      expect(ua.to_s).to include("Smolagents/#{Smolagents::VERSION}")
    end

    it "always includes Ruby version" do
      ua = described_class.new

      expect(ua.to_s).to include("Ruby/#{RUBY_VERSION}")
    end

    it "always includes contact URL with bot indicator" do
      ua = described_class.new

      expect(ua.to_s).to include("(+#{described_class::DEFAULT_CONTACT_URL}; bot)")
    end

    it "includes agent name and version when provided" do
      ua = described_class.new(agent_name: "MyAgent", agent_version: "2.5")

      expect(ua.to_s).to start_with("MyAgent/2.5")
    end

    it "includes tool name when provided" do
      ua = described_class.new(tool_name: "WebSearch")

      expect(ua.to_s).to include("Tool:WebSearch")
    end

    it "includes model ID when provided" do
      ua = described_class.new(model_id: "llama-3")

      expect(ua.to_s).to include("Model:llama-3")
    end

    it "uses custom contact URL when provided" do
      ua = described_class.new(contact_url: "https://example.com/bot")

      expect(ua.to_s).to include("(+https://example.com/bot; bot)")
    end

    it "orders components correctly" do
      ua = described_class.new(
        agent_name: "Agent",
        agent_version: "1.0",
        tool_name: "Tool",
        model_id: "model"
      )

      result = ua.to_s

      # Order: AgentName/Version Smolagents/VERSION Tool:Name Model:ID Ruby/VERSION (+URL; bot)
      parts = result.split
      expect(parts[0]).to eq("Agent/1.0")
      expect(parts[1]).to start_with("Smolagents/")
      expect(parts[2]).to eq("Tool:Tool")
      expect(parts[3]).to eq("Model:model")
      expect(parts[4]).to start_with("Ruby/")
    end

    it "produces RFC 7231 compliant format" do
      ua = described_class.new(
        agent_name: "TestBot",
        agent_version: "3.0",
        model_id: "test-model"
      )

      result = ua.to_s

      # RFC 7231: product/version tokens separated by space
      expect(result).to match(%r{^[\w./\-:]+ [\w./\-:]+ [\w./\-:]+ [\w./\-:]+ \(.+\)$})
    end
  end

  describe "#with_tool" do
    it "returns a new instance with tool context" do
      base = described_class.new(model_id: "gpt-4")
      with_tool = base.with_tool("VisitWebpage")

      expect(with_tool).to be_a(described_class)
      expect(with_tool).not_to be(base)
      expect(with_tool.tool_name).to eq("VisitWebpage")
    end

    it "preserves all original context" do
      base = described_class.new(
        agent_name: "Agent",
        agent_version: "1.0",
        model_id: "gpt-4",
        contact_url: "https://custom.url"
      )

      with_tool = base.with_tool("SearchTool")

      expect(with_tool.agent_name).to eq("Agent")
      expect(with_tool.agent_version).to eq("1.0")
      expect(with_tool.model_id).to eq("gpt-4")
      expect(with_tool.contact_url).to eq("https://custom.url")
    end

    it "does not modify the original instance" do
      base = described_class.new
      base.with_tool("SomeTool")

      expect(base.tool_name).to be_nil
    end

    it "can be chained" do
      ua = described_class.new
                          .with_tool("Tool1")

      expect(ua.tool_name).to eq("Tool1")
    end

    it "replaces existing tool name" do
      base = described_class.new(tool_name: "OldTool")
      with_new = base.with_tool("NewTool")

      expect(with_new.tool_name).to eq("NewTool")
    end
  end

  describe "#with_model" do
    it "returns a new instance with model context" do
      base = described_class.new(tool_name: "Search")
      with_model = base.with_model("claude-3")

      expect(with_model).to be_a(described_class)
      expect(with_model).not_to be(base)
      expect(with_model.model_id).to eq("claude-3")
    end

    it "preserves all original context" do
      base = described_class.new(
        agent_name: "Agent",
        agent_version: "2.0",
        tool_name: "Tool",
        contact_url: "https://custom.url"
      )

      with_model = base.with_model("new-model")

      expect(with_model.agent_name).to eq("Agent")
      expect(with_model.agent_version).to eq("2.0")
      expect(with_model.tool_name).to eq("Tool")
      expect(with_model.contact_url).to eq("https://custom.url")
    end

    it "does not modify the original instance" do
      base = described_class.new
      base.with_model("some-model")

      expect(base.model_id).to be_nil
    end

    it "sanitizes model ID automatically" do
      base = described_class.new
      with_model = base.with_model("org/model-name.gguf")

      expect(with_model.model_id).to eq("model-name")
    end
  end

  describe "model ID sanitization" do
    describe "path handling" do
      it "removes organization prefix" do
        ua = described_class.new(model_id: "meta-llama/Llama-2-7b")
        expect(ua.model_id).to eq("Llama-2-7b")
      end

      it "removes nested path components" do
        ua = described_class.new(model_id: "./models/local/my-model")
        expect(ua.model_id).to eq("my-model")
      end

      it "removes deep directory paths" do
        ua = described_class.new(model_id: "/home/user/models/test/model-name")
        expect(ua.model_id).to eq("model-name")
      end
    end

    describe "file extension removal" do
      it "removes .gguf extension" do
        ua = described_class.new(model_id: "model.gguf")
        expect(ua.model_id).to eq("model")
      end

      it "removes .GGUF extension (case insensitive)" do
        ua = described_class.new(model_id: "model.GGUF")
        expect(ua.model_id).to eq("model")
      end

      it "removes .bin extension" do
        ua = described_class.new(model_id: "model.bin")
        expect(ua.model_id).to eq("model")
      end

      it "removes .pt extension" do
        ua = described_class.new(model_id: "model.pt")
        expect(ua.model_id).to eq("model")
      end

      it "removes .safetensors extension" do
        ua = described_class.new(model_id: "model.safetensors")
        expect(ua.model_id).to eq("model")
      end

      it "handles path with extension" do
        ua = described_class.new(model_id: "./models/llama.gguf")
        expect(ua.model_id).to eq("llama")
      end
    end

    describe "date stamp removal" do
      it "removes 8-digit date suffixes" do
        ua = described_class.new(model_id: "claude-3-sonnet-20241022")
        expect(ua.model_id).to eq("claude-3-sonnet")
      end

      it "removes longer date suffixes" do
        ua = described_class.new(model_id: "model-202410221530")
        expect(ua.model_id).to eq("model")
      end

      it "preserves non-date numeric suffixes" do
        ua = described_class.new(model_id: "llama-7b")
        expect(ua.model_id).to eq("llama-7b")
      end

      it "preserves shorter numeric suffixes" do
        ua = described_class.new(model_id: "model-123")
        expect(ua.model_id).to eq("model-123")
      end
    end

    describe "character replacement" do
      it "replaces angle brackets with underscores" do
        ua = described_class.new(model_id: "model<test>name")
        expect(ua.model_id).to eq("model_test_name")
      end

      it "replaces pipe characters" do
        ua = described_class.new(model_id: "model|name")
        expect(ua.model_id).to eq("model_name")
      end

      it "replaces spaces" do
        ua = described_class.new(model_id: "model name with spaces")
        expect(ua.model_id).to eq("model_name_with_spaces")
      end

      it "preserves valid characters" do
        ua = described_class.new(model_id: "Model-Name_v1.2")
        expect(ua.model_id).to eq("Model-Name_v1.2")
      end

      it "replaces multiple special characters" do
        ua = described_class.new(model_id: "model@#$%name")
        expect(ua.model_id).to eq("model____name")
      end
    end

    describe "length limiting" do
      it "limits to MAX_MODEL_ID_LENGTH" do
        long_id = "a" * 100
        ua = described_class.new(model_id: long_id)

        expect(ua.model_id.length).to eq(described_class::MAX_MODEL_ID_LENGTH)
      end

      it "does not truncate shorter IDs" do
        short_id = "short-model"
        ua = described_class.new(model_id: short_id)

        expect(ua.model_id).to eq(short_id)
      end

      it "truncates exactly at MAX_MODEL_ID_LENGTH" do
        exactly_max = "a" * described_class::MAX_MODEL_ID_LENGTH
        ua = described_class.new(model_id: exactly_max)

        expect(ua.model_id.length).to eq(described_class::MAX_MODEL_ID_LENGTH)
      end
    end

    describe "nil and empty handling" do
      it "handles nil model_id" do
        ua = described_class.new(model_id: nil)
        expect(ua.model_id).to be_nil
      end

      it "handles empty string model_id" do
        ua = described_class.new(model_id: "")
        expect(ua.model_id).to be_nil
      end

      it "handles whitespace-only model_id by converting spaces to underscores" do
        # Whitespace is replaced with underscores before other processing
        ua = described_class.new(model_id: "   ")
        # Result depends on implementation - spaces become underscores
        expect(ua.model_id).to eq("___")
      end

      it "handles model_id that becomes empty after sanitization" do
        ua = described_class.new(model_id: "/.gguf")
        expect(ua.model_id).to be_nil
      end
    end

    describe "combined transformations" do
      it "handles org prefix, extension, and date together" do
        ua = described_class.new(model_id: "openai/gpt-4-turbo-20241022.gguf")
        expect(ua.model_id).to eq("gpt-4-turbo")
      end

      it "handles path with special chars and extension" do
        ua = described_class.new(model_id: "./models/my<special>model.safetensors")
        expect(ua.model_id).to eq("my_special_model")
      end
    end
  end

  describe "constants" do
    it "defines DEFAULT_CONTACT_URL" do
      expect(described_class::DEFAULT_CONTACT_URL).to eq("https://github.com/timlikesai/smolagents-ruby")
    end

    it "defines MAX_MODEL_ID_LENGTH" do
      expect(described_class::MAX_MODEL_ID_LENGTH).to eq(64)
    end
  end

  describe "re-exported class" do
    it "is accessible via Smolagents::UserAgent" do
      expect(Smolagents::UserAgent).to eq(described_class)
    end

    it "works identically via short path" do
      ua = Smolagents::UserAgent.new(model_id: "test-model")
      expect(ua.model_id).to eq("test-model")
    end
  end

  describe "immutability" do
    it "does not allow direct modification of agent_name" do
      ua = described_class.new(agent_name: "Original")
      expect { ua.agent_name = "Modified" }.to raise_error(NoMethodError)
    end

    it "does not allow direct modification of model_id" do
      ua = described_class.new(model_id: "original")
      expect { ua.model_id = "modified" }.to raise_error(NoMethodError)
    end
  end

  describe "header construction scenarios" do
    it "constructs header for basic web scraping tool" do
      ua = described_class.new(
        tool_name: "VisitWebpage",
        model_id: "gpt-4"
      )

      result = ua.to_s

      expect(result).to include("Tool:VisitWebpage")
      expect(result).to include("Model:gpt-4")
      expect(result).to include("bot")
    end

    it "constructs header for named agent with tool" do
      ua = described_class.new(
        agent_name: "ResearchBot",
        agent_version: "2.1",
        tool_name: "DuckDuckGoSearch",
        model_id: "nemotron-3-nano"
      )

      result = ua.to_s

      expect(result).to start_with("ResearchBot/2.1")
      expect(result).to include("Tool:DuckDuckGoSearch")
    end

    it "constructs header for local model" do
      ua = described_class.new(model_id: "./models/llama-3-8b-instruct.Q4_K_M.gguf")

      expect(ua.model_id).to eq("llama-3-8b-instruct.Q4_K_M")
    end

    it "constructs minimal header for simple requests" do
      ua = described_class.new

      result = ua.to_s
      # The format is: Smolagents/VERSION Ruby/VERSION (+URL; bot)
      # where (+URL; bot) counts as one component, but split sees multiple parts
      expect(result).to start_with("Smolagents/")
      expect(result).to include("Ruby/")
      expect(result).to include("(+")
      expect(result).to include("; bot)")
    end
  end
end
