require_relative "../concerns/result_formatting"

module Smolagents
  class ToolResult
    include Enumerable
    include Concerns::ResultFormatting

    attr_reader :data, :tool_name, :metadata

    def initialize(data, tool_name:, metadata: {})
      @data = deep_freeze(data)
      @tool_name = tool_name.to_s.freeze
      @metadata = metadata.merge(created_at: Time.now).freeze
    end

    def each(&)
      return enum_for(:each) { size } unless block_given?

      enumerable_data.each(&)
    end

    def size
      case @data
      when Array, Hash then @data.size
      when nil then 0
      else 1
      end
    end
    alias length size
    alias count size

    %i[select reject compact uniq reverse flatten].each do |method|
      define_method(method) { |*args, &block| chain(method) { block ? @data.public_send(method, *args, &block) : @data.public_send(method, *args) } }
    end
    alias filter select

    def map(&) = chain(:map) { @data.is_a?(Array) ? @data.map(&) : yield(@data) }
    alias collect map

    def flat_map(&) = chain(:flat_map) { @data.flat_map(&) }
    def sort_by(&) = chain(:sort_by) { @data.sort_by(&) }
    def sort(&block) = chain(:sort) { block ? @data.sort(&block) : @data.sort }
    def take(count) = chain(:take) { @data.take(count) }
    def drop(count) = chain(:drop) { @data.drop(count) }
    def take_while(&) = chain(:take_while) { @data.take_while(&) }
    def drop_while(&) = chain(:drop_while) { @data.drop_while(&) }
    def group_by(&) = chain(:group_by) { @data.group_by(&) }

    def partition(&)
      matching, non_matching = @data.partition(&)
      [self.class.new(matching, tool_name: @tool_name, metadata: { parent: @metadata[:created_at], op: :partition }),
       self.class.new(non_matching, tool_name: @tool_name, metadata: { parent: @metadata[:created_at], op: :partition })]
    end

    def min(&) = enumerable_data.min(&)
    def max(&) = enumerable_data.max(&)

    def average(&block)
      items = enumerable_data
      return 0.0 if items.empty?

      (block ? items.map(&block) : items).then { |values| values.sum.to_f / values.size }
    end

    def first(count = nil) = count ? take(count) : enumerable_data.first
    def last(count = nil) = count ? chain(:last) { @data.last(count) } : enumerable_data.last
    def pluck(key) = chain(:pluck) { @data.map { |item| item.is_a?(Hash) ? (item[key] || item[key.to_s]) : item } }

    def dig(*keys)
      @data.dig(*keys)
    rescue StandardError
      nil
    end

    def empty? = @data.nil? || (@data.respond_to?(:empty?) && @data.empty?)
    def include?(value) = (@data.respond_to?(:include?) && @data.include?(value)) || (error? && @metadata[:error].to_s.include?(value.to_s))
    alias member? include?

    def error? = @metadata[:success] == false || @metadata.key?(:error)
    def success? = !error?

    def to_a
      case @data
      when Array then @data.dup
      when Hash then @data.to_a
      when nil then []
      else [@data]
      end
    end
    alias to_ary to_a

    def to_h = { data: @data, tool_name: @tool_name, metadata: @metadata }
    alias to_hash to_h

    def to_s = as_markdown
    alias to_str to_s

    def as_json(*) = @data

    def inspect
      preview = case @data
                when Array then "[#{@data.size} items]"
                when Hash then "{#{@data.size} keys}"
                when String then @data.length > 40 ? "\"#{@data[0..37]}...\"" : @data.inspect
                else @data.inspect.then { |str| str.length > 40 ? "#{str[0..37]}..." : str }
                end
      "#<#{self.class} tool=#{@tool_name} data=#{preview}>"
    end

    def deconstruct = to_a
    def deconstruct_keys(keys) = { data: @data, tool_name: @tool_name, metadata: @metadata, empty?: empty?, error?: error? }.then { |hash| keys ? hash.slice(*keys) : hash }

    def ==(other) = other.is_a?(ToolResult) ? @data == other.data && @tool_name == other.tool_name : @data == other
    alias eql? ==

    def hash = [@data, @tool_name].hash

    def +(other)
      self.class.new(to_a + other.to_a, tool_name: "#{@tool_name}+#{other.tool_name}", metadata: { combined_from: [@tool_name, other.tool_name] })
    end

    def self.empty(tool_name: "unknown") = new([], tool_name: tool_name)

    def self.error(error, tool_name: "unknown", metadata: {})
      message = error.is_a?(Exception) ? "#{error.class}: #{error.message}" : error.to_s
      new(nil, tool_name: tool_name, metadata: metadata.merge(error: message, success: false))
    end

    private

    def enumerable_data
      case @data
      when Array, Hash then @data
      when nil then []
      else [@data]
      end
    end

    def chain(operation) = self.class.new(yield, tool_name: @tool_name, metadata: { parent: @metadata[:created_at], op: operation })

    def deep_freeze(obj)
      case obj
      when Array then obj.map { |item| deep_freeze(item) }.freeze
      when Hash then obj.transform_values { |val| deep_freeze(val) }.freeze
      when String then obj.frozen? ? obj : obj.dup.freeze
      else begin
        obj.freeze
      rescue StandardError
        obj
      end
      end
    end
  end
end
