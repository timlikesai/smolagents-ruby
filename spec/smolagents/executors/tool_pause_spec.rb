require_relative "../../../lib/smolagents/executors/tool_pause"

RSpec.describe Smolagents::Executors::ToolPause do
  describe "creating a ToolPause" do
    it "creates pause with required fields" do
      pause = described_class.new(
        tool_name: "search",
        arguments: { query: "Ruby" },
        result: ["Ruby 3.0", "Ruby 2.7"],
        duration: 0.5
      )

      expect(pause.tool_name).to eq("search")
      expect(pause.arguments).to eq({ query: "Ruby" })
      expect(pause.result).to eq(["Ruby 3.0", "Ruby 2.7"])
      expect(pause.duration).to eq(0.5)
    end

    it "creates pause with various result types" do
      # String result
      pause_string = described_class.new(
        tool_name: "web",
        arguments: {},
        result: "HTML content",
        duration: 1.0
      )
      expect(pause_string.result).to eq("HTML content")

      # Hash result
      pause_hash = described_class.new(
        tool_name: "api",
        arguments: {},
        result: { status: 200, data: "ok" },
        duration: 0.2
      )
      expect(pause_hash.result).to eq({ status: 200, data: "ok" })

      # Array result
      pause_array = described_class.new(
        tool_name: "search",
        arguments: {},
        result: [1, 2, 3],
        duration: 0.3
      )
      expect(pause_array.result).to eq([1, 2, 3])
    end
  end

  describe "#retrieval_tool?" do
    it "returns true for search tools" do
      pause = described_class.new(
        tool_name: "search",
        arguments: {},
        result: [],
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be true
    end

    it "returns true for web_search" do
      pause = described_class.new(
        tool_name: "web_search",
        arguments: {},
        result: [],
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be true
    end

    it "returns true for wikipedia" do
      pause = described_class.new(
        tool_name: "wikipedia",
        arguments: {},
        result: [],
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be true
    end

    it "returns true for duckduckgo_search" do
      pause = described_class.new(
        tool_name: "duckduckgo_search",
        arguments: {},
        result: [],
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be true
    end

    it "returns true for fetch" do
      pause = described_class.new(
        tool_name: "fetch",
        arguments: {},
        result: "",
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be true
    end

    it "returns true for http_request" do
      pause = described_class.new(
        tool_name: "http_request",
        arguments: {},
        result: {},
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be true
    end

    it "returns true for web" do
      pause = described_class.new(
        tool_name: "web",
        arguments: {},
        result: [],
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be true
    end

    it "returns true for bing_search" do
      pause = described_class.new(
        tool_name: "bing_search",
        arguments: {},
        result: [],
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be true
    end

    it "returns true for google_search" do
      pause = described_class.new(
        tool_name: "google_search",
        arguments: {},
        result: [],
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be true
    end

    it "returns true for searxng" do
      pause = described_class.new(
        tool_name: "searxng",
        arguments: {},
        result: [],
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be true
    end

    it "returns false for non-retrieval tools" do
      pause = described_class.new(
        tool_name: "calculate",
        arguments: {},
        result: 42,
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be false
    end

    it "returns false for custom tools" do
      pause = described_class.new(
        tool_name: "my_custom_tool",
        arguments: {},
        result: "data",
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be false
    end

    it "is case insensitive" do
      pause = described_class.new(
        tool_name: "SEARCH",
        arguments: {},
        result: [],
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be true
    end

    it "matches partial names" do
      pause = described_class.new(
        tool_name: "my_search_tool",
        arguments: {},
        result: [],
        duration: 0.1
      )

      expect(pause.retrieval_tool?).to be true
    end
  end

  describe "#final_answer?" do
    it "returns true for final_answer" do
      pause = described_class.new(
        tool_name: "final_answer",
        arguments: { answer: "42" },
        result: "42",
        duration: 0.0
      )

      expect(pause.final_answer?).to be true
    end

    it "returns false for other tools" do
      pause = described_class.new(
        tool_name: "search",
        arguments: {},
        result: [],
        duration: 0.1
      )

      expect(pause.final_answer?).to be false
    end

    it "is case sensitive (must be exact)" do
      pause = described_class.new(
        tool_name: "FINAL_ANSWER",
        arguments: {},
        result: "answer",
        duration: 0.0
      )

      expect(pause.final_answer?).to be false
    end

    it "returns false for similar names" do
      pause = described_class.new(
        tool_name: "final_answer_signal",
        arguments: {},
        result: "data",
        duration: 0.0
      )

      expect(pause.final_answer?).to be false
    end
  end

  describe "#to_s" do
    it "returns formatted string" do
      pause = described_class.new(
        tool_name: "search",
        arguments: {},
        result: [],
        duration: 0.1
      )

      expect(pause.to_s).to eq("ToolPause[search]")
    end

    it "includes tool name in output" do
      pause = described_class.new(
        tool_name: "web_fetch",
        arguments: {},
        result: "html",
        duration: 0.5
      )

      expect(pause.to_s).to include("web_fetch")
    end

    it "formats for final_answer" do
      pause = described_class.new(
        tool_name: "final_answer",
        arguments: { answer: "42" },
        result: "42",
        duration: 0.0
      )

      expect(pause.to_s).to eq("ToolPause[final_answer]")
    end
  end

  describe "Data.define behavior" do
    it "is immutable" do
      pause = described_class.new(
        tool_name: "search",
        arguments: {},
        result: [],
        duration: 0.1
      )

      # Data.define objects don't have setter methods
      expect { pause.tool_name = "other" }.to raise_error(NoMethodError)
    end

    it "is a Data instance" do
      pause = described_class.new(
        tool_name: "search",
        arguments: {},
        result: [],
        duration: 0.1
      )

      expect(pause).to be_a(Data)
    end
  end

  describe "usage patterns" do
    it "represents successful tool execution" do
      pause = described_class.new(
        tool_name: "search",
        arguments: { query: "Ruby 3.0" },
        result: [
          { title: "Ruby 3.0 Released", url: "https://..." }
        ],
        duration: 0.234
      )

      expect(pause.tool_name).to eq("search")
      expect(pause.retrieval_tool?).to be true
      expect(pause.result).to be_a(Array)
      expect(pause.duration).to be_a(Float)
    end

    it "represents final_answer completion" do
      pause = described_class.new(
        tool_name: "final_answer",
        arguments: { answer: "Ruby 3.0 was released in December 2020" },
        result: "Ruby 3.0 was released in December 2020",
        duration: 0.0
      )

      expect(pause.final_answer?).to be true
      expect(pause.retrieval_tool?).to be false
    end

    it "distinguishes between different tool types" do
      search_pause = described_class.new(
        tool_name: "search",
        arguments: {},
        result: [],
        duration: 0.1
      )

      calculate_pause = described_class.new(
        tool_name: "calculate",
        arguments: {},
        result: 42,
        duration: 0.05
      )

      expect(search_pause.retrieval_tool?).to be true
      expect(calculate_pause.retrieval_tool?).to be false
    end
  end

  describe "duration tracking" do
    it "stores exact duration" do
      pause = described_class.new(
        tool_name: "search",
        arguments: {},
        result: [],
        duration: 1.234567
      )

      expect(pause.duration).to eq(1.234567)
    end

    it "handles zero duration" do
      pause = described_class.new(
        tool_name: "cache_hit",
        arguments: {},
        result: "cached",
        duration: 0.0
      )

      expect(pause.duration).to eq(0.0)
    end

    it "handles negative durations gracefully" do
      # While not normal, Data allows it
      pause = described_class.new(
        tool_name: "test",
        arguments: {},
        result: "data",
        duration: -0.1
      )

      expect(pause.duration).to eq(-0.1)
    end
  end

  describe "arguments handling" do
    it "stores empty arguments" do
      pause = described_class.new(
        tool_name: "random",
        arguments: {},
        result: 42,
        duration: 0.1
      )

      expect(pause.arguments).to eq({})
    end

    it "stores single argument" do
      pause = described_class.new(
        tool_name: "search",
        arguments: { query: "Ruby" },
        result: [],
        duration: 0.1
      )

      expect(pause.arguments).to eq({ query: "Ruby" })
    end

    it "stores multiple arguments" do
      pause = described_class.new(
        tool_name: "api_call",
        arguments: { endpoint: "/users", limit: 10, offset: 0 },
        result: [],
        duration: 0.2
      )

      expect(pause.arguments.keys).to include(:endpoint, :limit, :offset)
    end

    it "preserves argument types" do
      pause = described_class.new(
        tool_name: "tool",
        arguments: {
          string: "value",
          number: 42,
          array: [1, 2],
          hash: { nested: true }
        },
        result: nil,
        duration: 0.1
      )

      expect(pause.arguments[:string]).to be_a(String)
      expect(pause.arguments[:number]).to be_a(Integer)
      expect(pause.arguments[:array]).to be_a(Array)
      expect(pause.arguments[:hash]).to be_a(Hash)
    end
  end
end
