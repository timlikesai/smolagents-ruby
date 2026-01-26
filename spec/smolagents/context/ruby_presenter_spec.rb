require "spec_helper"
require "smolagents/context/ruby_presenter"

RSpec.describe Smolagents::Context::RubyPresenter do
  describe ".section" do
    it "formats a section with header and content" do
      result = described_class.section("Goal", "Find Ruby release notes")
      expect(result).to eq("# == Goal ==\n# Find Ruby release notes")
    end

    it "handles multiline content" do
      content = "Line 1\nLine 2\nLine 3"
      result = described_class.section("Content", content)
      expect(result).to eq("# == Content ==\n# Line 1\n# Line 2\n# Line 3")
    end

    it "preserves empty lines in content" do
      content = "Before\n\nAfter"
      result = described_class.section("Test", content)
      expect(result).to include("# Before\n# \n# After")
    end
  end

  describe ".list_section" do
    it "formats a numbered list" do
      items = %w[Search Extract Summarize]
      result = described_class.list_section("Plan", items)
      expect(result).to include("# == Plan ==")
      expect(result).to include("# 1. [ ] Search")
      expect(result).to include("# 2. [ ] Extract")
      expect(result).to include("# 3. [ ] Summarize")
    end

    it "applies markers to items" do
      items = %w[Done Doing Todo]
      markers = { 0 => "\u2713", 1 => "\u2192" }
      result = described_class.list_section("Progress", items, markers:)
      expect(result).to include("# 1. [\u2713] Done")
      expect(result).to include("# 2. [\u2192] Doing")
      expect(result).to include("# 3. [ ] Todo")
    end

    it "handles empty list" do
      result = described_class.list_section("Empty", [])
      expect(result).to eq("# == Empty ==\n")
    end
  end

  describe ".kv_section" do
    it "formats key-value pairs" do
      pairs = { step: 3, budget: 1000, status: "active" }
      result = described_class.kv_section("State", pairs)
      expect(result).to include("# == State ==")
      expect(result).to include("# step  : 3")
      expect(result).to include("# budget: 1000")
      expect(result).to include("# status: active")
    end

    it "aligns values by longest key" do
      pairs = { a: 1, longer_key: 2 }
      result = described_class.kv_section("Test", pairs)
      lines = result.split("\n")
      expect(lines[1]).to match(/^# a         : 1$/)
      expect(lines[2]).to match(/^# longer_key: 2$/)
    end

    it "handles empty pairs" do
      result = described_class.kv_section("Empty", {})
      expect(result).to eq("# == Empty ==\n")
    end

    it "handles symbol and string keys" do
      pairs = { "string_key" => "value1", symbol_key: "value2" }
      result = described_class.kv_section("Mixed", pairs)
      expect(result).to include("# string_key: value1")
      expect(result).to include("# symbol_key: value2")
    end
  end

  describe ".tools_section" do
    it "formats tools with signatures and descriptions" do
      tools = [
        { name: :search, signature: "search(query:)", description: "Web search" },
        { name: :final_answer, signature: "final_answer(answer:)", description: "Complete" }
      ]
      result = described_class.tools_section(tools)
      expect(result).to include("# == Available Tools ==")
      expect(result).to include("# search(query:)")
      expect(result).to include("# Web search")
      expect(result).to include("# final_answer(answer:)")
    end

    it "aligns descriptions" do
      tools = [
        { name: :short, signature: "short()", description: "Short" },
        { name: :very_long_name, signature: "very_long_name(arg:)", description: "Long" }
      ]
      result = described_class.tools_section(tools)
      lines = result.split("\n")
      expect(lines[1]).to match(/^# short\(\)\s+# Short$/)
      expect(lines[2]).to match(/^# very_long_name\(arg:\)\s+# Long$/)
    end

    it "handles empty tools" do
      result = described_class.tools_section([])
      expect(result).to eq("# == Available Tools ==\n")
    end
  end

  describe ".continuation" do
    it "returns continuation prompt" do
      result = described_class.continuation
      expect(result).to eq("# Continue from here:")
    end
  end

  describe ".boxed_header" do
    it "creates a boxed header" do
      result = described_class.boxed_header("CONTEXT")
      expect(result).to include("\u2554")
      expect(result).to include("\u2557")
      expect(result).to include("\u2551")
      expect(result).to include("\u255a")
      expect(result).to include("\u255d")
      expect(result).to include("CONTEXT")
    end

    it "centers the title" do
      result = described_class.boxed_header("TEST")
      middle_line = result.split("\n")[1]
      expect(middle_line).to include("TEST")
      expect(middle_line.length).to eq(result.split("\n")[0].length)
    end
  end

  describe ".context_block" do
    it "combines sections with blank lines" do
      sections = ["# Section 1", "# Section 2", "# Section 3"]
      result = described_class.context_block(sections)
      expect(result).to eq("# Section 1\n\n# Section 2\n\n# Section 3")
    end

    it "filters out nil sections" do
      sections = ["# Section 1", nil, "# Section 3"]
      result = described_class.context_block(sections)
      expect(result).to eq("# Section 1\n\n# Section 3")
    end

    it "handles empty array" do
      result = described_class.context_block([])
      expect(result).to eq("")
    end
  end

  describe ".progress" do
    it "formats progress indicator" do
      result = described_class.progress(3, 10)
      expect(result).to eq("step 3 of 10 (7 remaining)")
    end

    it "handles final step" do
      result = described_class.progress(10, 10)
      expect(result).to eq("step 10 of 10 (0 remaining)")
    end

    it "handles first step" do
      result = described_class.progress(1, 5)
      expect(result).to eq("step 1 of 5 (4 remaining)")
    end
  end

  describe ".status" do
    it "formats success status" do
      result = described_class.status("search", :success)
      expect(result).to eq("search \u2713")
    end

    it "formats failure status" do
      result = described_class.status("search", :failure)
      expect(result).to eq("search \u2717")
    end

    it "formats pending status" do
      result = described_class.status("search", :pending)
      expect(result).to eq("search \u2192")
    end

    it "includes detail when provided" do
      result = described_class.status("search", :success, "1.2s")
      expect(result).to eq("search \u2713 (1.2s)")
    end

    it "handles unknown status" do
      result = described_class.status("search", :unknown)
      expect(result).to eq("search ?")
    end
  end

  describe "integration" do
    it "builds a complete context block" do
      goal = described_class.section("Goal", "Find and summarize Ruby 4.0 release notes")
      state = described_class.kv_section("Execution State", {
                                           step: described_class.progress(3, 10),
                                           last_tool: described_class.status("search", :success, "1.2s"),
                                           budget: "~2000 tokens remaining"
                                         })
      plan = described_class.list_section("Plan", [
                                            "Search for Ruby 4.0 release notes",
                                            "Extract key features",
                                            "Summarize findings"
                                          ], markers: { 0 => "\u2713", 1 => "\u2192" })

      result = described_class.context_block([
                                               described_class.boxed_header("CONTEXT"),
                                               goal,
                                               state,
                                               plan,
                                               described_class.continuation
                                             ])

      expect(result).to include("CONTEXT")
      expect(result).to include("Goal")
      expect(result).to include("Execution State")
      expect(result).to include("Plan")
      expect(result).to include("Continue from here:")
    end
  end
end
