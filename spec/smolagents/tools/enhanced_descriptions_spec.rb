RSpec.describe "Enhanced Tool Descriptions (Research-Backed Format)", type: :feature do
  # Research shows effective tool descriptions need:
  # 1. 3-4+ sentences explaining what the tool does
  # 2. "Use when" section for positive guidance
  # 3. "Do NOT use" section for negative guidance
  # 4. "Returns" section describing output format
  # (NO examples in description - examples confuse small models)

  # Helper to get description without instantiating (for tools that require API keys)
  def description_for(tool_class)
    # SearchTool subclasses store description in their config
    if tool_class.respond_to?(:config) && tool_class.config.respond_to?(:description)
      tool_class.config.description
    else
      tool_class.instance_variable_get(:@description)
    end
  end

  shared_examples "research-backed description format" do |tool_class|
    let(:description) { description_for(tool_class) }

    it "has a multi-line description (3+ lines)" do
      lines = description.lines.reject { |l| l.strip.empty? }
      expect(lines.count).to be >= 3,
                             "Expected 3+ lines, got #{lines.count}. Description:\n#{description}"
    end

    it "includes 'Use when' guidance" do
      expect(description).to match(/use when/i),
                             "Missing 'Use when' guidance in:\n#{description}"
    end

    it "includes 'Do NOT use' guidance" do
      expect(description).to match(/do not use/i),
                             "Missing 'Do NOT use' guidance in:\n#{description}"
    end

    it "includes 'Returns' description" do
      expect(description).to match(/returns/i),
                             "Missing 'Returns' description in:\n#{description}"
    end

    it "does not contain code examples in description" do
      # Examples like `tool.call(...)` or method calls with parentheses and quoted strings
      expect(description).not_to match(/\w+\([^)]*:\s*["'][^"']+["']\)/),
                                 "Found code example in description (examples confuse small models):\n#{description}"
    end
  end

  # Tools that don't require API keys - test with instantiation
  describe Smolagents::Tools::FinalAnswerTool do
    let(:tool) { described_class.new }

    it "has a multi-line description (3+ lines)" do
      lines = tool.description.lines.reject { |l| l.strip.empty? }
      expect(lines.count).to be >= 3
    end

    it "includes 'Use when' guidance" do
      expect(tool.description).to match(/use when/i)
    end

    it "includes 'Do NOT use' guidance" do
      expect(tool.description).to match(/do not use/i)
    end

    it "includes 'Returns' description" do
      expect(tool.description).to match(/returns/i)
    end

    it "does not contain code examples in description" do
      expect(tool.description).not_to match(/\w+\([^)]*:\s*["'][^"']+["']\)/)
    end
  end

  describe Smolagents::Tools::VisitWebpageTool do
    let(:tool) { described_class.new }

    it "has a multi-line description (3+ lines)" do
      lines = tool.description.lines.reject { |l| l.strip.empty? }
      expect(lines.count).to be >= 3
    end

    it "includes 'Use when' guidance" do
      expect(tool.description).to match(/use when/i)
    end

    it "includes 'Do NOT use' guidance" do
      expect(tool.description).to match(/do not use/i)
    end

    it "includes 'Returns' description" do
      expect(tool.description).to match(/returns/i)
    end

    it "does not contain code examples in description" do
      expect(tool.description).not_to match(/\w+\([^)]*:\s*["'][^"']+["']\)/)
    end
  end

  describe Smolagents::Tools::UserInputTool do
    let(:tool) { described_class.new }

    it "has a multi-line description (3+ lines)" do
      lines = tool.description.lines.reject { |l| l.strip.empty? }
      expect(lines.count).to be >= 3
    end

    it "includes 'Use when' guidance" do
      expect(tool.description).to match(/use when/i)
    end

    it "includes 'Do NOT use' guidance" do
      expect(tool.description).to match(/do not use/i)
    end

    it "includes 'Returns' description" do
      expect(tool.description).to match(/returns/i)
    end

    it "does not contain code examples in description" do
      expect(tool.description).not_to match(/\w+\([^)]*:\s*["'][^"']+["']\)/)
    end
  end

  describe Smolagents::Tools::RubyInterpreterTool do
    let(:tool) { described_class.new }

    it "has a multi-line description (3+ lines)" do
      lines = tool.description.lines.reject { |l| l.strip.empty? }
      expect(lines.count).to be >= 3
    end

    it "includes 'Use when' guidance" do
      expect(tool.description).to match(/use when/i)
    end

    it "includes 'Do NOT use' guidance" do
      expect(tool.description).to match(/do not use/i)
    end

    it "includes 'Returns' description" do
      expect(tool.description).to match(/returns/i)
    end

    it "does not contain code examples in description" do
      expect(tool.description).not_to match(/\w+\([^)]*:\s*["'][^"']+["']\)/)
    end
  end

  # Tools that require API keys - test at class level to avoid instantiation
  describe "GoogleSearchTool description" do
    it_behaves_like "research-backed description format", Smolagents::Tools::GoogleSearchTool
  end

  describe "BraveSearchTool description" do
    it_behaves_like "research-backed description format", Smolagents::Tools::BraveSearchTool
  end

  describe "BingSearchTool description" do
    it_behaves_like "research-backed description format", Smolagents::Tools::BingSearchTool
  end

  describe "SearxngSearchTool description" do
    it_behaves_like "research-backed description format", Smolagents::Tools::SearxngSearchTool
  end

  # These tools already had good descriptions - basic verification
  describe Smolagents::Tools::DuckDuckGoSearchTool do
    let(:tool) { described_class.new }

    it "has a description" do
      expect(tool.description).not_to be_empty
    end
  end

  describe Smolagents::Tools::WikipediaSearchTool do
    let(:tool) { described_class.new }

    it "has a description" do
      expect(tool.description).not_to be_empty
    end
  end

  describe "search tools return format consistency" do
    let(:search_tool_classes) do
      [
        Smolagents::Tools::GoogleSearchTool,
        Smolagents::Tools::BraveSearchTool,
        Smolagents::Tools::BingSearchTool,
        Smolagents::Tools::SearxngSearchTool
      ]
    end

    it "all describe their return format with title/link/description" do
      search_tool_classes.each do |tool_class|
        description = description_for(tool_class)
        expect(description).to match(/returns.*results.*title.*link.*description/i),
                               "#{tool_class.name} should describe return format"
      end
    end
  end
end
