# frozen_string_literal: true

module Smolagents
  # Lazy, streaming result object for paginated or large tool outputs.
  class LazyToolResult
    include Enumerable

    attr_reader :tool_name, :metadata, :source

    DEFAULT_PAGE_SIZE = 10

    def initialize(source, tool_name:, page_size: DEFAULT_PAGE_SIZE, metadata: {}, &fetcher)
      raise ArgumentError, "Fetcher block is required" unless fetcher

      @source = source
      @tool_name = tool_name.to_s.freeze
      @page_size = page_size
      @metadata = metadata.merge(lazy: true, created_at: Time.now).freeze
      @fetcher = fetcher
      @cache = []
      @current_page = 0
      @exhausted = false
      @mutex = Mutex.new
    end

    def each(&)
      return to_enum(:each) unless block_given?

      @cache.each(&)
      (new_items = fetch_next_page
       break if new_items.empty?

       new_items.each(&)) until exhausted?
    end

    def lazy = to_enum(:each).lazy

    def take(count)
      [].tap do |items|
        each do |item|
          items << item
          break if items.size >= count
        end
      end.then { |collected| to_tool_result_with(collected) }
    end

    def first(count = nil) = count ? take(count) : each.first

    %i[select reject map].each { |m| define_method(m) { |&block| to_tool_result_with(lazy.public_send(m, &block).force) } }
    alias filter select
    alias collect map

    def to_tool_result = to_tool_result_with(to_a)
    alias force to_tool_result

    def to_a = each.to_a
    def to_s = to_tool_result.to_s
    def exhausted? = @mutex.synchronize { @exhausted }
    def empty? = first.nil?
    def cached_count = @mutex.synchronize { @cache.size }
    def current_page = @mutex.synchronize { @current_page }

    def reset!
      @mutex.synchronize do
        @cache = []
        @current_page = 0
        @exhausted = false
      end
    end

    def prefetch(pages = 1)
      pages.times do
        break if exhausted?

        fetch_next_page
      end
      self
    end

    def inspect = "#<#{self.class} tool=#{@tool_name} cached=#{cached_count} status=#{exhausted? ? "exhausted" : "streaming"}>"

    def self.from_array(data, tool_name:, page_size: DEFAULT_PAGE_SIZE) = new(data, tool_name: tool_name, page_size: page_size) do |_, page|
      data.each_slice(page_size).to_a[page] || []
    end

    def self.from_enumerator(enum, tool_name:, page_size: DEFAULT_PAGE_SIZE)
      slicer = enum.each_slice(page_size)
      new(enum, tool_name: tool_name, page_size: page_size) do |_, _|
        slicer.next
      rescue StandardError
        []
      end
    end

    private

    def fetch_next_page
      @mutex.synchronize do
        return [] if @exhausted

        new_items = @fetcher.call(@source, @current_page)
        if new_items.nil? || new_items.empty?
          (@exhausted = true
           return [])
        end
        @exhausted = true if new_items.size < @page_size
        @cache.concat(new_items)
        @current_page += 1
        new_items
      end
    end

    def to_tool_result_with(data) = ToolResult.new(data, tool_name: @tool_name, metadata: @metadata.merge(evaluated_from_lazy: true))
  end
end
