module Smolagents
  # Composable tool pipeline for deterministic, chainable tool execution.
  #
  # @example Basic pipeline
  #   pipeline = Smolagents::Pipeline.new
  #   pipeline.empty?  #=> true
  #   pipeline.call(:final_answer, answer: "hello").length  #=> 1
  class Pipeline
    # Step types for pipeline execution.
    module Step
      # Tool call step with argument resolution.
      # Supports static args, :input/:prev symbols, and dynamic blocks.
      Call = Data.define(:tool_name, :static_args, :dynamic_block) do
        def execute(prev_result, registry:)
          tool = registry.get(tool_name.to_s) || raise(ArgumentError, "Unknown tool: #{tool_name}")
          tool.call(**resolve_args(prev_result))
        end

        private

        def resolve_args(prev_result)
          args = static_args.transform_values { |v| resolve_value(v, prev_result) }
          if dynamic_block && dynamic_block.call(prev_result).is_a?(Hash)
            args = args.merge(dynamic_block.call(prev_result))
          end
          args.transform_keys(&:to_sym)
        end

        def resolve_value(value, prev_result)
          case value
          when :prev, :prev_result then prev_result.data
          when :input then resolve_input(prev_result)
          when Symbol then prev_result[value] || prev_result[value.to_s]
          else value
          end
        end

        def resolve_input(prev_result)
          data = prev_result.data
          data.is_a?(Hash) && data.key?(:input) ? data[:input] : data
        end
      end

      # Transform step wrapping ToolResult operations.
      BLOCK_OPERATIONS = %i[select reject map flat_map compact uniq reverse flatten sort_by].freeze
      ARG_OPERATIONS = %i[take drop pluck].freeze

      Transform = Data.define(:operation, :block, :args) do
        def execute(prev_result, _registry:)
          return execute_custom(prev_result) if operation == :custom
          return prev_result.public_send(operation, &block) if Step::BLOCK_OPERATIONS.include?(operation)
          return prev_result.public_send(operation, args.first) if Step::ARG_OPERATIONS.include?(operation)

          raise ArgumentError, "Unknown transform operation: #{operation}"
        end

        def execute_custom(prev_result)
          result = block.call(prev_result)
          result.is_a?(ToolResult) ? result : wrap_result(result, prev_result)
        end

        private

        def wrap_result(data, prev_result)
          ToolResult.new(data, tool_name: "transform", metadata: { from: prev_result.tool_name })
        end
      end
    end

    attr_reader :steps

    def initialize(steps: [])
      @steps = steps.freeze
    end

    # Add a tool call step.
    # @param tool_name [Symbol] Tool to call
    # @param static_args [Hash] Arguments (symbols like :input resolve to prev result)
    # @yield [prev_result] Optional block for dynamic arguments
    # @return [Pipeline] New pipeline with step added
    def call(tool_name, **static_args, &dynamic_block)
      add_step(Step::Call.new(tool_name.to_sym, static_args, dynamic_block))
    end

    alias then call

    # Add a custom transform step.
    # @yield [prev_result] Block that transforms the result
    # @return [Pipeline] New pipeline with transform added
    def transform(&block)
      add_step(Step::Transform.new(:custom, block, []))
    end

    # Transform methods mirror ToolResult's chainable transforms.
    def select(&block) = add_step(Step::Transform.new(:select, block, []))
    def reject(&block) = add_step(Step::Transform.new(:reject, block, []))
    def map(&block) = add_step(Step::Transform.new(:map, block, []))
    def flat_map(&block) = add_step(Step::Transform.new(:flat_map, block, []))
    def sort_by(&block) = add_step(Step::Transform.new(:sort_by, block, []))
    def compact = add_step(Step::Transform.new(:compact, nil, []))
    def uniq = add_step(Step::Transform.new(:uniq, nil, []))
    def reverse = add_step(Step::Transform.new(:reverse, nil, []))
    def flatten = add_step(Step::Transform.new(:flatten, nil, []))
    def take(count) = add_step(Step::Transform.new(:take, nil, [count]))
    def drop(count) = add_step(Step::Transform.new(:drop, nil, [count]))
    def pluck(key) = add_step(Step::Transform.new(:pluck, nil, [key]))

    # Execute the pipeline.
    # @param input [Hash] Input arguments (available as :input in first step)
    # @return [ToolResult] Final result
    def run(**input)
      initial = ToolResult.new(input, tool_name: "pipeline_input", metadata: { pipeline: true })
      steps.reduce(initial) { |prev, step| step.execute(prev, registry: Tools) }
    end

    alias result run
    alias execute run

    # Convert pipeline to a reusable Tool.
    # @param name [String] Tool name
    # @param description [String] Tool description
    # @param inputs [Hash, nil] Input spec (inferred if nil)
    # @return [Tool] Tool that executes this pipeline
    def as_tool(name, description, inputs: nil)
      pipeline = self
      inferred_inputs = inputs || infer_inputs
      Tools.define_tool(name, description:, inputs: inferred_inputs, output_type: "any") do |**kwargs|
        pipeline.run(**kwargs).data
      end
    end

    def empty? = steps.empty?
    def length = steps.length
    alias size length

    def inspect
      step_summary = steps.map do |step|
        case step
        when Step::Call then "call(:#{step.tool_name})"
        when Step::Transform then step.operation.to_s
        end
      end.join(" -> ")
      "#<Pipeline [#{step_summary}]>"
    end

    private

    def add_step(step)
      self.class.new(steps: steps + [step])
    end

    def infer_inputs
      first_call = steps.find { |s| s.is_a?(Step::Call) }
      return { "input" => { type: "any", description: "Pipeline input" } } unless first_call

      first_call.static_args.each_with_object({}) do |(key, value), inputs|
        next unless %i[input prev].include?(value)

        inputs[key.to_s] = { type: "string", description: "Input for #{key}" }
      end
    end
  end
end
