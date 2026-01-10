# frozen_string_literal: true

require_relative "transform_operations"

module Smolagents
  # Refinements for fluent tool API. Activate with `using Smolagents::Refinements`.
  module Refinements
    class << self
      attr_accessor :tools, :default_options

      def configure(tools = nil, **kwargs, &block)
        option_keys = %i[timeout max_retries default_options]
        if tools.nil?
          @tools = kwargs.except(*option_keys).transform_keys(&:to_sym)
          @default_options = kwargs.slice(*option_keys)
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
      def reset! = (@tools = {}) && (@default_options = {})
      def find_tool(*names) = names.lazy.map { |n| tool(n) }.find(&:itself)

      def call_tool(tool, tool_name, **)
        raise NoMethodError, "No #{tool_name} tool configured" unless tool

        result = tool.call(**)
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
          param = case method
                  when :visit then :url
                  when :calculate then :code
                  else :query
                  end
          Smolagents::Refinements.call_tool(tool, method.to_s, param => self, **options)
        end
      end

      def extract_from(text, **options)
        tool = Smolagents::Refinements.find_tool(:regex, :extract)
        return Smolagents::Refinements.call_tool(tool, "regex", text: text, pattern: self, **options) if tool

        Smolagents::ToolResult.new(text.scan(Regexp.new(self)), tool_name: "regex")
      end

      def as_regex(options = 0) = Regexp.new(self, options)
      def render(**vars) = vars.each_with_object(dup) { |(k, v), s| s.gsub!("{{#{k}}}", v.to_s) }
    end

    refine Array do
      def to_tool_result(tool_name: "array", **meta) = Smolagents::ToolResult.new(self, tool_name: tool_name, metadata: meta)

      def transform(operations)
        tool = Smolagents::Refinements.tool(:data_transform)
        return Smolagents::Refinements.call_tool(tool, "transform", data: self, operations: operations) if tool

        Smolagents::ToolResult.new(TransformOperations.apply(self, operations), tool_name: "transform")
      end
    end

    refine Hash do
      def to_tool_result(tool_name: "hash", **meta) = Smolagents::ToolResult.new(self, tool_name: tool_name, metadata: meta)

      def dig_path(path)
        path.scan(/([a-zA-Z_]\w*)|\[(\d+)\]/).reduce(self) do |obj, (key, idx)|
          case obj
          when Hash then obj[key] || obj[key.to_sym]
          when Array then idx ? obj[idx.to_i] : nil
          end
        end
      end

      def query(path)
        tool = Smolagents::Refinements.tool(:json_query)
        return Smolagents::Refinements.call_tool(tool, "query", data: self, path: path) if tool

        Smolagents::ToolResult.new(dig_path(path), tool_name: "query")
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
