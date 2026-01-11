module Smolagents
  class ToolPipeline
    Step = Data.define(:tool_name, :static_args, :dynamic_args, :transform, :name) do
      def initialize(tool_name:, static_args: {}, dynamic_args: nil, transform: nil, name: nil)
        super(tool_name: tool_name.to_s, static_args: static_args.freeze, dynamic_args: dynamic_args, transform: transform, name: name&.to_s)
      end

      def label = name || tool_name
    end

    ExecutionResult = Data.define(:output, :steps, :duration_ms, :success) do
      def initialize(output:, steps:, duration_ms:, success: true) = super
      def to_tool_result = output
      def success? = success
      def summary = "Pipeline completed in #{duration_ms}ms (#{steps.size} steps)\n" + steps.map { |s| "  #{s[:step]}: #{s[:duration_ms]}ms" }.join("\n")
    end

    attr_reader :tools, :steps, :name

    def initialize(tools, name: nil)
      @tools = normalize_tools(tools)
      @steps = []
      @name = name
    end

    def self.build(tools, name: nil, &block) = new(tools, name: name).tap { |p| p.instance_eval(&block) if block }

    def self.execute(tools, *steps)
      new(tools).tap { |p| steps.each { |s| p.add_step(s[:tool], **(s[:args] || {}), dynamic_args: s[:args_from], transform: s[:transform]) } }.run
    end

    def step(tool_name, name: nil, **static_args, &dynamic_block) = add_step(tool_name, name: name, dynamic_args: dynamic_block, **static_args)
    alias then_do step

    def transform(name = "transform", &block)
      (@steps << Step.new(tool_name: "__transform__", transform: block, name: name)
       self)
    end

    def add_step(tool_name, dynamic_args: nil, transform: nil, name: nil, **static_args)
      @steps << Step.new(tool_name: tool_name, static_args: static_args, dynamic_args: dynamic_args, transform: transform, name: name)
      self
    end

    def insert_step(index, tool_name, **) = @steps.insert(index, Step.new(tool_name: tool_name, **))
    def remove_step(index_or_name) = index_or_name.is_a?(Integer) ? @steps.delete_at(index_or_name) : @steps.reject! { |s| s.label == index_or_name.to_s }

    def clear_steps
      (@steps = []
       self)
    end

    def run(initial_input = nil) = execute_pipeline(initial_input).output
    alias call run

    def run_with_details(initial_input = nil) = execute_pipeline(initial_input)

    def empty? = @steps.empty?
    def size = @steps.size
    alias length size

    def describe
      ([@name ? "Pipeline: #{@name}" : "Pipeline"] + @steps.map.with_index do |s, i|
        "  #{i + 1}. #{s.label}#{"(#{s.static_args.keys.join(", ")})" unless s.static_args.empty?}#{" [dynamic]" if s.dynamic_args}"
      end).join("\n")
    end

    def inspect = "#<#{self.class} steps=#{@steps.size} tools=#{@tools.size}>"

    def +(other) = self.class.new(@tools.merge(other.tools)).tap { |c| (@steps + other.steps).each { |s| c.steps << s } }
    def dup = self.class.new(@tools.dup, name: @name).tap { |c| @steps.each { |s| c.steps << s } }

    private

    def normalize_tools(tools)
      case tools
      when Hash then tools.transform_keys(&:to_s)
      when Array then tools.to_h { |t| [t.name.to_s, t] }
      else raise ArgumentError, "Tools must be a Hash or Array, got #{tools.class}"
      end
    end

    def measure_time
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      [yield, ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)]
    end

    def execute_pipeline(initial_input)
      current_result = wrap_as_tool_result(initial_input, "input")
      step_results = []

      _, total_duration = measure_time do
        @steps.each_with_index do |step, index|
          result, step_duration = measure_time { execute_step(step, current_result) }
          step_results << { step: step.label, index: index, duration_ms: step_duration, success: true }
          current_result = result
        rescue StandardError => e
          step_results << { step: step.label, index: index, duration_ms: 0, success: false, error: e.message }
          return ExecutionResult.new(output: ToolResult.error(e, tool_name: step.tool_name), steps: step_results, duration_ms: 0, success: false)
        end
      end

      ExecutionResult.new(output: current_result, steps: step_results, duration_ms: total_duration)
    end

    def execute_step(step, previous_result)
      return wrap_as_tool_result(step.transform.call(previous_result), "transform") if step.tool_name == "__transform__"

      tool = @tools[step.tool_name] || raise(ArgumentError, "Unknown tool: #{step.tool_name}")
      args = step.static_args.dup
      args = args.merge(step.dynamic_args.call(previous_result).transform_keys(&:to_sym)) if step.dynamic_args

      result = tool.call(**args)
      result = step.transform.call(result) if step.transform
      wrap_as_tool_result(result, step.tool_name)
    end

    def wrap_as_tool_result(value, tool_name)
      case value
      when ToolResult then value
      when nil then ToolResult.empty(tool_name: tool_name)
      else ToolResult.new(value, tool_name: tool_name)
      end
    end
  end
end
