# frozen_string_literal: true

RSpec.describe Smolagents::LazyToolResult do
  let(:all_data) do
    (1..25).map { |i| { id: i, name: "Item #{i}" } }
  end

  let(:lazy_result) do
    pages = all_data.each_slice(10).to_a

    described_class.new("test query", tool_name: "test_tool", page_size: 10) do |_source, page|
      pages[page] || []
    end
  end

  describe "#initialize" do
    it "creates a lazy result with source and tool name" do
      expect(lazy_result.source).to eq("test query")
      expect(lazy_result.tool_name).to eq("test_tool")
    end

    it "requires a fetcher block" do
      expect do
        described_class.new("query", tool_name: "test")
      end.to raise_error(ArgumentError, /Fetcher block is required/)
    end

    it "includes lazy flag in metadata" do
      expect(lazy_result.metadata[:lazy]).to be true
    end

    it "includes created_at in metadata" do
      expect(lazy_result.metadata[:created_at]).to be_a(Time)
    end
  end

  describe "#each" do
    it "yields all items across pages" do
      items = []
      lazy_result.each { |item| items << item }
      expect(items.size).to eq(25)
    end

    it "returns Enumerator when no block given" do
      expect(lazy_result.each).to be_a(Enumerator)
    end

    it "caches results for subsequent iterations" do
      fetch_count = 0
      counting_result = described_class.new("query", tool_name: "test") do |_, page|
        fetch_count += 1
        page < 2 ? [{ id: page }] : []
      end

      counting_result.to_a
      initial_count = fetch_count

      counting_result.to_a
      expect(fetch_count).to eq(initial_count) # No additional fetches
    end

    it "fetches pages lazily" do
      fetch_count = 0
      counting_result = described_class.new("query", tool_name: "test", page_size: 5) do |_, page|
        fetch_count += 1
        page < 5 ? Array.new(5) { { id: page * 5 + _1 } } : []
      end

      # Only iterate over 3 items
      counting_result.each.take(3).to_a
      expect(fetch_count).to eq(1) # Only first page fetched
    end
  end

  describe "#lazy" do
    it "returns a lazy enumerator" do
      expect(lazy_result.lazy).to be_a(Enumerator::Lazy)
    end

    it "enables lazy chaining" do
      result = lazy_result.lazy.select { |item| item[:id] > 20 }.take(3).force
      expect(result.size).to eq(3)
      expect(result.first[:id]).to eq(21)
    end

    it "supports early termination" do
      fetch_count = 0
      counting_result = described_class.new("query", tool_name: "test", page_size: 5) do |_, page|
        fetch_count += 1
        page < 10 ? Array.new(5) { { id: page * 5 + _1 } } : []
      end

      # Take only 3 items with lazy evaluation
      counting_result.lazy.take(3).force
      expect(fetch_count).to eq(1) # Only first page needed
    end
  end

  describe "#take" do
    it "returns ToolResult with first n items" do
      result = lazy_result.take(5)

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.count).to eq(5)
      expect(result.first[:id]).to eq(1)
    end

    it "handles taking more than available" do
      result = lazy_result.take(100)
      expect(result.count).to eq(25)
    end

    it "fetches only necessary pages" do
      fetch_count = 0
      counting_result = described_class.new("query", tool_name: "test", page_size: 10) do |_, page|
        fetch_count += 1
        page < 3 ? Array.new(10) { { id: page * 10 + _1 } } : []
      end

      counting_result.take(5)
      expect(fetch_count).to eq(1) # Only first page needed for 5 items
    end
  end

  describe "#first" do
    it "returns first item without argument" do
      expect(lazy_result.first).to eq({ id: 1, name: "Item 1" })
    end

    it "returns ToolResult with first n items" do
      result = lazy_result.first(3)
      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.count).to eq(3)
    end
  end

  describe "#select" do
    it "returns ToolResult with filtered items" do
      result = lazy_result.select { |item| item[:id] > 20 }

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.count).to eq(5)
      expect(result.all? { |item| item[:id] > 20 }).to be true
    end
  end

  describe "#reject" do
    it "returns ToolResult without rejected items" do
      result = lazy_result.reject { |item| item[:id] <= 20 }

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.count).to eq(5)
    end
  end

  describe "#map" do
    it "returns ToolResult with mapped values" do
      result = lazy_result.map { |item| item[:name] }

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.first).to eq("Item 1")
      expect(result.last).to eq("Item 25")
    end
  end

  describe "#to_tool_result" do
    it "converts to fully-loaded ToolResult" do
      result = lazy_result.to_tool_result

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.count).to eq(25)
      expect(result.tool_name).to eq("test_tool")
    end

    it "includes evaluated_from_lazy in metadata" do
      result = lazy_result.to_tool_result
      expect(result.metadata[:evaluated_from_lazy]).to be true
    end

    it "is aliased as force" do
      expect(lazy_result.method(:force)).to eq(lazy_result.method(:to_tool_result))
    end
  end

  describe "#to_a" do
    it "returns array of all items" do
      arr = lazy_result.to_a
      expect(arr).to be_an(Array)
      expect(arr.size).to eq(25)
    end
  end

  describe "#to_s" do
    it "returns string representation" do
      str = lazy_result.to_s
      expect(str).to be_a(String)
      expect(str).to include("Item 1")
    end
  end

  describe "#exhausted?" do
    it "returns false initially" do
      expect(lazy_result.exhausted?).to be false
    end

    it "returns true after all pages fetched" do
      lazy_result.to_a
      expect(lazy_result.exhausted?).to be true
    end
  end

  describe "#empty?" do
    it "returns false for non-empty result" do
      expect(lazy_result.empty?).to be false
    end

    it "returns true for empty result" do
      empty_result = described_class.new("query", tool_name: "test") { |_, _| [] }
      expect(empty_result.empty?).to be true
    end
  end

  describe "#cached_count" do
    it "returns count of cached items" do
      expect(lazy_result.cached_count).to eq(0)

      lazy_result.take(5)
      expect(lazy_result.cached_count).to eq(10) # Full first page cached
    end
  end

  describe "#current_page" do
    it "returns current page number" do
      expect(lazy_result.current_page).to eq(0)

      lazy_result.take(5)
      expect(lazy_result.current_page).to eq(1)
    end
  end

  describe "#reset!" do
    it "clears cache and resets state" do
      lazy_result.to_a
      expect(lazy_result.exhausted?).to be true
      expect(lazy_result.cached_count).to eq(25)

      lazy_result.reset!

      expect(lazy_result.exhausted?).to be false
      expect(lazy_result.cached_count).to eq(0)
      expect(lazy_result.current_page).to eq(0)
    end
  end

  describe "#prefetch" do
    it "prefetches specified number of pages" do
      lazy_result.prefetch(2)
      expect(lazy_result.cached_count).to eq(20)
      expect(lazy_result.current_page).to eq(2)
    end

    it "stops at exhaustion" do
      lazy_result.prefetch(10) # More than available pages
      expect(lazy_result.exhausted?).to be true
      expect(lazy_result.cached_count).to eq(25)
    end

    it "returns self for chaining" do
      expect(lazy_result.prefetch(1)).to eq(lazy_result)
    end
  end

  describe "#inspect" do
    it "shows streaming status" do
      expect(lazy_result.inspect).to include("streaming")
    end

    it "shows exhausted status after completion" do
      lazy_result.to_a
      expect(lazy_result.inspect).to include("exhausted")
    end

    it "shows cached count" do
      lazy_result.take(5)
      expect(lazy_result.inspect).to include("cached=10")
    end
  end

  describe ".from_array" do
    it "creates lazy result from existing array" do
      result = described_class.from_array(all_data, tool_name: "test", page_size: 10)

      expect(result).to be_a(described_class)
      expect(result.to_a).to eq(all_data)
    end

    it "simulates pagination" do
      result = described_class.from_array(all_data, tool_name: "test", page_size: 10)

      # Should only "fetch" first page
      result.take(5)
      expect(result.current_page).to eq(1)
    end
  end

  describe ".from_enumerator" do
    it "creates lazy result from enumerator" do
      enum = (1..10).each
      result = described_class.from_enumerator(enum, tool_name: "test", page_size: 3)

      expect(result.to_a).to eq((1..10).to_a)
    end

    it "handles enumerator exhaustion" do
      enum = (1..5).each
      result = described_class.from_enumerator(enum, tool_name: "test", page_size: 10)

      expect(result.to_a).to eq([1, 2, 3, 4, 5])
      expect(result.exhausted?).to be true
    end
  end

  describe "thread safety" do
    it "handles concurrent access" do
      threads = 10.times.map do
        Thread.new { lazy_result.take(10).to_a }
      end

      results = threads.map(&:value)

      # All threads should get consistent results
      expect(results.uniq.size).to eq(1)
      expect(results.first.size).to eq(10)
    end
  end

  describe "error handling" do
    it "propagates errors from fetcher" do
      # Return full page to avoid early exhaustion, then error on page 1
      error_result = described_class.new("query", tool_name: "test", page_size: 5) do |_, page|
        raise "Fetch error" if page > 0
        Array.new(5) { |i| { id: i } }
      end

      expect { error_result.to_a }.to raise_error(RuntimeError, "Fetch error")
    end
  end

  describe "Enumerable integration" do
    it "supports find" do
      item = lazy_result.find { |i| i[:id] == 15 }
      expect(item).to eq({ id: 15, name: "Item 15" })
    end

    it "supports any?" do
      expect(lazy_result.any? { |i| i[:id] == 10 }).to be true
    end

    it "supports none?" do
      expect(lazy_result.none? { |i| i[:id] > 100 }).to be true
    end

    it "supports count" do
      expect(lazy_result.count).to eq(25)
    end

    it "supports reduce" do
      sum = lazy_result.reduce(0) { |acc, item| acc + item[:id] }
      expect(sum).to eq((1..25).sum)
    end
  end
end
