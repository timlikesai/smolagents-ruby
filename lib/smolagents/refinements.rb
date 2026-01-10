# frozen_string_literal: true

module Smolagents
  # Refinements for fluent tool API. Activate with `using Smolagents::Refinements`.
  module Refinements
    class << self
      attr_accessor :tools, :default_options

      def configure(tools = nil, **kwargs, &block)
        option_keys = %i[timeout max_retries default_options]
        if tools.nil?
          @tools = kwargs.reject { |k, _| option_keys.include?(k) }.transform_keys(&:to_sym)
          @default_options = kwargs.select { |k, _| option_keys.include?(k) }
        else
          @tools = tools.transform_keys(&:to_sym)
          @default_options = kwargs
        end
        instance_eval(&block) if block
        self
      end

      def register(name, tool) = (@tools ||= {})[name.to_sym] = tool
      def tool(name) = @tools&.[](name.to_sym)
      def tool?(name) = @tools&.key?(name.to_sym) || false
      def reset! = (@tools = {}; @default_options = {})
      def find_tool(*names) = names.lazy.map { |n| tool(n) }.find(&:itself)

      def call_tool(tool, tool_name, **kwargs)
        raise NoMethodError, "No #{tool_name} tool configured" unless tool
        result = tool.call(**kwargs)
        result.is_a?(ToolResult) ? result : ToolResult.new(result, tool_name: tool_name)
      end
    end

    TOOL_METHODS = {
      search: %i[search web_search], visit: %i[visit visit_webpage],
      wikipedia: %i[wikipedia wikipedia_search], calculate: %i[calculate ruby_interpreter]
    }.freeze

    refine String do
      TOOL_METHODS.each do |method, alternatives|
        define_method(method) do |**options|
          tool = Smolagents::Refinements.find_tool(*alternatives)
          param = method == :visit ? :url : (method == :calculate ? :code : :query)
          Smolagents::Refinements.call_tool(tool, method.to_s, param => self, **options)
        end
      end

      def extract_from(text, **options)
        tool = Smolagents::Refinements.find_tool(:regex, :extract)
        tool ? Smolagents::Refinements.call_tool(tool, "regex", text: text, pattern: self, **options) : Smolagents::ToolResult.new(text.scan(Regexp.new(self)), tool_name: "regex")
      end

      def as_regex(options = 0) = Regexp.new(self, options)
      def render(**variables) = variables.reduce(dup) { |s, (k, v)| s.gsub!("{{#{k}}}", v.to_s); s }
    end

    refine Array do
      def to_tool_result(tool_name: "array", **metadata) = Smolagents::ToolResult.new(self, tool_name: tool_name, metadata: metadata)

      def transform(operations)
        tool = Smolagents::Refinements.tool(:data_transform)
        tool ? Smolagents::Refinements.call_tool(tool, "transform", data: self, operations: operations) : apply_transforms(operations)
      end

      private

      def apply_transforms(operations)
        result = operations.reduce(self) do |data, op|
          type = op[:type] || op["type"]
          key = op[:key] || op["key"]
          count = op[:count] || op["count"]
          case type
          when "select" then data.select { |i| matches?(i, op) }
          when "reject" then data.reject { |i| matches?(i, op) }
          when "sort_by" then data.sort_by { |i| i[key] || i[key.to_sym] }
          when "take" then data.take(count || 10)
          when "drop" then data.drop(count || 0)
          when "uniq" then key ? data.uniq { |i| i[key] || i[key.to_sym] } : data.uniq
          when "pluck" then data.map { |i| i[key] || i[key.to_sym] }
          else data
          end
        end
        Smolagents::ToolResult.new(result, tool_name: "transform")
      end

      def matches?(item, op)
        cond = op[:condition] || op["condition"]
        return true unless cond
        field = cond[:field] || cond["field"]
        compare_op = cond[:op] || cond["op"] || "="
        value = cond.key?(:value) ? cond[:value] : cond["value"]
        item_val = item.is_a?(Hash) ? (item[field] || item[field.to_s] || item[field.to_sym]) : item
        ops = { "=" => :==, "==" => :==, "!=" => :!=, ">" => :>, "<" => :<, ">=" => :>=, "<=" => :<= }
        ops[compare_op] ? item_val.send(ops[compare_op], value) : true
      end
    end

    refine Hash do
      def to_tool_result(tool_name: "hash", **metadata) = Smolagents::ToolResult.new(self, tool_name: tool_name, metadata: metadata)

      def dig_path(path)
        path.scan(/([a-zA-Z_]\w*)|\[(\d+)\]/).reduce(self) do |obj, (key, idx)|
          case obj
          when Hash then obj[key] || obj[key.to_sym]
          when Array then idx ? obj[idx.to_i] : nil
          else nil
          end
        end
      end

      def query(path)
        tool = Smolagents::Refinements.tool(:json_query)
        tool ? Smolagents::Refinements.call_tool(tool, "query", data: self, path: path) : Smolagents::ToolResult.new(dig_path(path), tool_name: "query")
      end
    end

    refine Integer do
      def times_result(&block) = Smolagents::ToolResult.new(times.map(&block), tool_name: "generate")
    end

    refine Range do
      def to_tool_result(tool_name: "range") = Smolagents::ToolResult.new(to_a, tool_name: tool_name)
    end

    refine Proc do
      def as_transform(name: "custom") = { type: "__proc__", proc: self, name: name }
    end
  end

  module AllRefinements
    include Refinements
  end
end
