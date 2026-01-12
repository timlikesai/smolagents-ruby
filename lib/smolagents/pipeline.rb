module Smolagents
  # Composable tool pipeline for deterministic, chainable tool execution.
  #
  # @example Basic pipeline
  #   pipeline = Pipeline.new
  #     .call(:google_search, query: :input)
  #     .then(:visit_webpage) { |prev| { url: prev.first[:url] } }
  #     .select { |r| r[:content].length > 100 }
  #
  #   result = pipeline.run(query: "Ruby 4.0")
  #
  # @example Convert to tool
  #   research_tool = pipeline.as_tool("research", "Deep research on a topic")
  #   agent = Agents::Code.new(model:, tools: [research_tool])
  #
  class Pipeline
    # Step types for pipeline execution
    module Step
      # A tool call step - executes a tool with resolved arguments
      Call = Data.define(:tool_name, :static_args, :dynamic_block) do
        def execute(prev_result, registry:)
          tool = registry.get(tool_name.to_s) || raise(ArgumentError, "Unknown tool: #{tool_name}")
          args = resolve_args(prev_result)
          tool.call(**args)
        end

        private

        def resolve_args(prev_result)
          # Start with static args, resolving special symbols
          args = static_args.transform_values { |v| resolve_value(v, prev_result) }

          # Merge dynamic args from block if provided
          if dynamic_block
            dynamic_result = dynamic_block.call(prev_result)
            args = args.merge(dynamic_result) if dynamic_result.is_a?(Hash)
          end

          args.transform_keys(&:to_sym)
        end

        def resolve_value(value, prev_result)
          case value
          when :prev, :prev_result
            prev_result.data
          when :input
            # :input resolves to the :input key if present, otherwise whole data
            if prev_result.data.is_a?(Hash) && prev_result.data.key?(:input)
              prev_result.data[:input]
            else
              prev_result.data
            end
          when Symbol
            # Try to dig the symbol as a key from prev data
            prev_result[value] || prev_result[value.to_s]
          else
            value
          end
        end
      end

      # A transform step - applies a block to the result
      Transform = Data.define(:operation, :block, :args) do
        def execute(prev_result, registry:)
          case operation
          when :custom
            result = block.call(prev_result)
            result.is_a?(ToolResult) ? result : wrap_result(result, prev_result)
          when :select, :reject, :map, :flat_map, :compact, :uniq, :reverse, :flatten
            prev_result.public_send(operation, &block)
          when :sort_by
            prev_result.sort_by(&block)
          when :take, :drop
            prev_result.public_send(operation, args.first)
          when :pluck
            prev_result.pluck(args.first)
          else
            raise ArgumentError, "Unknown transform operation: #{operation}"
          end
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

    # Add a tool call step
    #
    # @param tool_name [Symbol, String] Name of the tool to call
    # @param static_args [Hash] Static arguments (symbols like :input resolve to prev result)
    # @yield [prev_result] Optional block for dynamic argument resolution
    # @return [Pipeline] New pipeline with step added
    def call(tool_name, **static_args, &dynamic_block)
      add_step(Step::Call.new(tool_name.to_sym, static_args, dynamic_block))
    end

    # Alias for call - reads better after first step
    alias then call

    # Add a custom transform step
    #
    # @yield [prev_result] Block that transforms the result
    # @return [Pipeline] New pipeline with step added
    def transform(&block)
      add_step(Step::Transform.new(:custom, block, []))
    end

    # ToolResult-style chainable transforms
    def select(&block) = add_step(Step::Transform.new(:select, block, []))
    def reject(&block) = add_step(Step::Transform.new(:reject, block, []))
    def map(&block) = add_step(Step::Transform.new(:map, block, []))
    def flat_map(&block) = add_step(Step::Transform.new(:flat_map, block, []))
    def sort_by(&block) = add_step(Step::Transform.new(:sort_by, block, []))
    def compact = add_step(Step::Transform.new(:compact, nil, []))
    def uniq = add_step(Step::Transform.new(:uniq, nil, []))
    def reverse = add_step(Step::Transform.new(:reverse, nil, []))
    def flatten = add_step(Step::Transform.new(:flatten, nil, []))
    def take(n) = add_step(Step::Transform.new(:take, nil, [n]))
    def drop(n) = add_step(Step::Transform.new(:drop, nil, [n]))
    def pluck(key) = add_step(Step::Transform.new(:pluck, nil, [key]))

    # Execute the pipeline
    #
    # @param input [Hash] Input arguments (available as :input in first step)
    # @return [ToolResult] Final result
    def run(**input)
      initial = ToolResult.new(input, tool_name: "pipeline_input", metadata: { pipeline: true })

      steps.reduce(initial) do |prev_result, step|
        step.execute(prev_result, registry: Tools)
      end
    end

    # Alias for run
    alias result run
    alias execute run

    # Convert this pipeline to a Tool
    #
    # @param name [String] Tool name
    # @param description [String] Tool description
    # @param inputs [Hash] Input specification (optional, inferred if not provided)
    # @return [Tool] A tool that executes this pipeline
    def as_tool(name, description, inputs: nil)
      pipeline = self
      inferred_inputs = inputs || infer_inputs

      Tools.define_tool(
        name,
        description: description,
        inputs: inferred_inputs,
        output_type: "any"
      ) { |**kwargs| pipeline.run(**kwargs).data }
    end

    # Check if pipeline is empty
    def empty? = steps.empty?

    # Number of steps
    def length = steps.length
    alias size length

    # Inspect for debugging
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
      # Look at first Call step to infer inputs
      first_call = steps.find { |s| s.is_a?(Step::Call) }
      return { "input" => { type: "any", description: "Pipeline input" } } unless first_call

      first_call.static_args.each_with_object({}) do |(key, value), inputs|
        next unless %i[input prev].include?(value)

        inputs[key.to_s] = { type: "string", description: "Input for #{key}" }
      end
    end
  end
end
