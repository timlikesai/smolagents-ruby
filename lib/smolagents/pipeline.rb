module Smolagents
  # Composable tool pipeline for deterministic, chainable tool execution.
  #
  # Pipeline provides a declarative way to compose multiple tool calls and data
  # transformations into a single, reusable unit. Pipelines are immutable - each
  # method returns a new Pipeline instance, enabling safe method chaining.
  #
  # Pipelines can:
  # - Chain multiple tool calls with automatic argument resolution
  # - Apply ToolResult-style transformations (select, map, pluck, etc.)
  # - Be converted into reusable Tool instances
  # - Execute deterministically with predictable behavior
  #
  # @example Basic pipeline with tool chaining
  #   pipeline = Pipeline.new
  #     .call(:google_search, query: :input)
  #     .then(:visit_webpage) { |prev| { url: prev.first[:url] } }
  #     .select { |r| r[:content].length > 100 }
  #
  #   result = pipeline.run(query: "Ruby 4.0")
  #
  # @example Using module-level convenience method
  #   result = Smolagents.run(:search, query: "Ruby")
  #     .then(:visit) { |r| { url: r.first[:url] } }
  #     .pluck(:content)
  #     .run
  #
  # @example Convert pipeline to a reusable tool
  #   research_tool = pipeline.as_tool("research", "Deep research on a topic")
  #   agent = Agents::CodeAgent.new(model:, tools: [research_tool])
  #
  # @example Multi-step research pipeline
  #   research = Pipeline.new
  #     .call(:google_search, query: :input)
  #     .take(3)
  #     .map { |r| { url: r[:url], title: r[:title] } }
  #
  #   tool = research.as_tool("quick_research", "Search and return top 3 results")
  #
  # @see Step::Call Tool invocation step type
  # @see Step::Transform Data transformation step type
  # @see ToolResult Chainable result wrapper returned by pipelines
  #
  class Pipeline
    # Contains step types for pipeline execution.
    #
    # Steps are immutable value objects (using Data.define) that represent
    # individual operations in a pipeline. Each step knows how to execute
    # itself given a previous result and a tool registry.
    #
    # @see Call Step that invokes a tool
    # @see Transform Step that transforms data
    #
    module Step
      # A tool call step that executes a registered tool with resolved arguments.
      #
      # Call steps handle argument resolution through several mechanisms:
      # - Static arguments passed directly
      # - Special symbols (:input, :prev) that resolve to previous result data
      # - Symbol keys that dig into previous result data
      # - Dynamic blocks for complex argument computation
      #
      # @example Static arguments
      #   Call.new(:search, { query: "Ruby 4.0" }, nil)
      #
      # @example Input resolution
      #   Call.new(:search, { query: :input }, nil)
      #   # Resolves :input to pipeline input or prev.data[:input]
      #
      # @example Dynamic block
      #   Call.new(:visit, {}, ->(prev) { { url: prev.first[:url] } })
      #
      # @!attribute [r] tool_name
      #   @return [Symbol] Name of the tool to execute
      # @!attribute [r] static_args
      #   @return [Hash] Static arguments (may contain symbols for resolution)
      # @!attribute [r] dynamic_block
      #   @return [Proc, nil] Optional block for dynamic argument computation
      #
      Call = Data.define(:tool_name, :static_args, :dynamic_block) do
        # Executes the tool call with resolved arguments.
        #
        # @param prev_result [ToolResult] Result from the previous step
        # @param registry [#get] Tool registry that responds to #get(tool_name)
        # @return [ToolResult] Result from the tool execution
        # @raise [ArgumentError] If the tool is not found in the registry
        def execute(prev_result, registry:)
          tool = registry.get(tool_name.to_s) || raise(ArgumentError, "Unknown tool: #{tool_name}")
          args = resolve_args(prev_result)
          tool.call(**args)
        end

        private

        # Resolves all arguments by combining static args and dynamic block results.
        #
        # @param prev_result [ToolResult] Result from the previous step
        # @return [Hash<Symbol, Object>] Resolved argument hash
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

        # Resolves a single value, handling special symbols.
        #
        # @param value [Object] The value to resolve
        # @param prev_result [ToolResult] Result from the previous step
        # @return [Object] The resolved value
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

      # A transform step that applies operations to the previous result.
      #
      # Transform steps wrap ToolResult's chainable methods (select, map, etc.)
      # and also support custom transformations via blocks. All transforms
      # return new ToolResult instances, preserving immutability.
      #
      # @example Built-in operations
      #   Transform.new(:select, ->(x) { x[:active] }, [])
      #   Transform.new(:take, nil, [5])
      #   Transform.new(:pluck, nil, [:name])
      #
      # @example Custom transform
      #   Transform.new(:custom, ->(r) { r.data.sum { |x| x[:value] } }, [])
      #
      # @!attribute [r] operation
      #   @return [Symbol] Operation type (:select, :map, :take, :custom, etc.)
      # @!attribute [r] block
      #   @return [Proc, nil] Block for the operation (if applicable)
      # @!attribute [r] args
      #   @return [Array] Additional arguments for the operation
      #
      BLOCK_OPERATIONS = %i[select reject map flat_map compact uniq reverse flatten sort_by].freeze
      ARG_OPERATIONS = %i[take drop pluck].freeze

      Transform = Data.define(:operation, :block, :args) do
        # Executes the transform operation on the previous result.
        #
        # @param prev_result [ToolResult] Result from the previous step
        # @param registry [Object] Tool registry (unused for transforms)
        # @return [ToolResult] Transformed result
        # @raise [ArgumentError] If the operation is unknown
        def execute(prev_result, registry:)
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

        # Wraps raw data in a ToolResult for consistency.
        #
        # @param data [Object] The data to wrap
        # @param prev_result [ToolResult] The previous result (for metadata)
        # @return [ToolResult] Wrapped result
        def wrap_result(data, prev_result)
          ToolResult.new(data, tool_name: "transform", metadata: { from: prev_result.tool_name })
        end
      end
    end

    # @!attribute [r] steps
    #   @return [Array<Step::Call, Step::Transform>] Frozen array of pipeline steps
    attr_reader :steps

    # Creates a new Pipeline instance.
    #
    # @param steps [Array<Step::Call, Step::Transform>] Initial steps (default: empty)
    # @return [Pipeline] New pipeline instance
    #
    # @example Create empty pipeline
    #   pipeline = Pipeline.new
    #
    # @example Create with pre-defined steps
    #   steps = [Pipeline::Step::Call.new(:search, {query: "test"}, nil)]
    #   pipeline = Pipeline.new(steps: steps)
    def initialize(steps: [])
      @steps = steps.freeze
    end

    # @!group Building Pipelines

    # Adds a tool call step to the pipeline.
    #
    # Tool calls can receive arguments in three ways:
    # - Static values: `call(:tool, arg: "literal")`
    # - Symbol resolution: `call(:tool, arg: :input)` - resolves from previous result
    # - Dynamic block: `call(:tool) { |prev| { arg: prev.first[:value] } }`
    #
    # @param tool_name [Symbol, String] Name of the tool to call
    # @param static_args [Hash] Static arguments (symbols like :input resolve to prev result)
    # @yield [prev_result] Optional block for dynamic argument resolution
    # @yieldparam prev_result [ToolResult] The result from the previous step
    # @yieldreturn [Hash] Arguments to merge with static_args
    # @return [Pipeline] New pipeline with the call step added
    #
    # @example Static arguments
    #   Pipeline.new.call(:search, query: "Ruby 4.0")
    #
    # @example Symbol resolution
    #   Pipeline.new.call(:search, query: :input)
    #
    # @example Dynamic arguments
    #   Pipeline.new
    #     .call(:search, query: "Ruby")
    #     .call(:visit) { |prev| { url: prev.first[:url] } }
    def call(tool_name, **static_args, &dynamic_block)
      add_step(Step::Call.new(tool_name.to_sym, static_args, dynamic_block))
    end

    # Alias for {#call} - reads better after the first step in a chain.
    #
    # @see #call
    alias then call

    # Adds a custom transform step with arbitrary logic.
    #
    # Use this when the built-in transform methods (select, map, etc.) are
    # not sufficient. The block receives the full ToolResult and can return
    # either a ToolResult or raw data (which will be wrapped automatically).
    #
    # @yield [prev_result] Block that transforms the result
    # @yieldparam prev_result [ToolResult] The result from the previous step
    # @yieldreturn [ToolResult, Object] Transformed result or data
    # @return [Pipeline] New pipeline with the transform step added
    #
    # @example Custom aggregation
    #   Pipeline.new
    #     .call(:search, query: "Ruby")
    #     .transform { |r| r.data.sum { |item| item[:score] } }
    def transform(&block)
      add_step(Step::Transform.new(:custom, block, []))
    end

    # @!endgroup

    # @!group Transform Methods
    # These methods mirror ToolResult's chainable transforms.

    # Filters elements that match the block.
    #
    # @yield [element] Block that returns true for elements to keep
    # @return [Pipeline] New pipeline with the select step added
    # @see ToolResult#select
    def select(&block) = add_step(Step::Transform.new(:select, block, []))

    # Filters elements that do not match the block.
    #
    # @yield [element] Block that returns true for elements to remove
    # @return [Pipeline] New pipeline with the reject step added
    # @see ToolResult#reject
    def reject(&block) = add_step(Step::Transform.new(:reject, block, []))

    # Transforms each element using the block.
    #
    # @yield [element] Block that transforms each element
    # @return [Pipeline] New pipeline with the map step added
    # @see ToolResult#map
    def map(&block) = add_step(Step::Transform.new(:map, block, []))

    # Maps and flattens in one step.
    #
    # @yield [element] Block that returns an array for each element
    # @return [Pipeline] New pipeline with the flat_map step added
    # @see ToolResult#flat_map
    def flat_map(&block) = add_step(Step::Transform.new(:flat_map, block, []))

    # Sorts elements by the block's return value.
    #
    # @yield [element] Block that returns a sortable value
    # @return [Pipeline] New pipeline with the sort_by step added
    # @see ToolResult#sort_by
    def sort_by(&block) = add_step(Step::Transform.new(:sort_by, block, []))

    # Removes nil values.
    #
    # @return [Pipeline] New pipeline with the compact step added
    # @see ToolResult#compact
    def compact = add_step(Step::Transform.new(:compact, nil, []))

    # Removes duplicate values.
    #
    # @return [Pipeline] New pipeline with the uniq step added
    # @see ToolResult#uniq
    def uniq = add_step(Step::Transform.new(:uniq, nil, []))

    # Reverses the order of elements.
    #
    # @return [Pipeline] New pipeline with the reverse step added
    # @see ToolResult#reverse
    def reverse = add_step(Step::Transform.new(:reverse, nil, []))

    # Flattens nested arrays.
    #
    # @return [Pipeline] New pipeline with the flatten step added
    # @see ToolResult#flatten
    def flatten = add_step(Step::Transform.new(:flatten, nil, []))

    # Takes the first n elements.
    #
    # @param count [Integer] Number of elements to take
    # @return [Pipeline] New pipeline with the take step added
    # @see ToolResult#take
    def take(count) = add_step(Step::Transform.new(:take, nil, [count]))

    # Drops the first n elements.
    #
    # @param count [Integer] Number of elements to drop
    # @return [Pipeline] New pipeline with the drop step added
    # @see ToolResult#drop
    def drop(count) = add_step(Step::Transform.new(:drop, nil, [count]))

    # Extracts a single key from each element.
    #
    # @param key [Symbol, String] Key to extract from each element
    # @return [Pipeline] New pipeline with the pluck step added
    # @see ToolResult#pluck
    def pluck(key) = add_step(Step::Transform.new(:pluck, nil, [key]))

    # @!endgroup

    # @!group Execution

    # Executes the pipeline and returns the final result.
    #
    # The pipeline is executed step-by-step, with each step receiving the
    # result from the previous step. The initial result is created from
    # the input arguments.
    #
    # @param input [Hash] Input arguments (available as :input in first step)
    # @return [ToolResult] Final result after all steps execute
    # @raise [ArgumentError] If a tool call references an unknown tool
    #
    # @example Execute with input
    #   pipeline = Pipeline.new.call(:search, query: :input)
    #   result = pipeline.run(input: "Ruby 4.0")
    #
    # @example Execute without input
    #   pipeline = Pipeline.new.call(:search, query: "Ruby")
    #   result = pipeline.run
    def run(**input)
      initial = ToolResult.new(input, tool_name: "pipeline_input", metadata: { pipeline: true })

      steps.reduce(initial) do |prev_result, step|
        step.execute(prev_result, registry: Tools)
      end
    end

    # Alias for {#run}.
    # @see #run
    alias result run

    # Alias for {#run}.
    # @see #run
    alias execute run

    # @!endgroup

    # @!group Conversion

    # Converts this pipeline to a reusable Tool.
    #
    # The resulting tool can be used with agents or other pipelines,
    # encapsulating the entire pipeline's behavior in a single tool.
    #
    # @param name [String] Tool name (should be a valid identifier)
    # @param description [String] Tool description for LLM understanding
    # @param inputs [Hash, nil] Input specification (inferred from pipeline if nil)
    # @return [Tool] A tool that executes this pipeline
    #
    # @example Create a tool from a pipeline
    #   research = Pipeline.new
    #     .call(:search, query: :input)
    #     .take(3)
    #     .pluck(:url)
    #
    #   tool = research.as_tool("quick_search", "Search and return top 3 URLs")
    #   agent = CodeAgent.new(model: model, tools: [tool])
    #
    # @example With custom input specification
    #   tool = pipeline.as_tool(
    #     "my_tool",
    #     "Description",
    #     inputs: { "query" => { type: "string", description: "Search query" } }
    #   )
    def as_tool(name, description, inputs: nil)
      pipeline = self
      inferred_inputs = inputs || infer_inputs

      Tools.define_tool(
        name,
        description:,
        inputs: inferred_inputs,
        output_type: "any"
      ) { |**kwargs| pipeline.run(**kwargs).data }
    end

    # @!endgroup

    # @!group Introspection

    # Returns true if the pipeline has no steps.
    #
    # @return [Boolean] True if empty
    def empty? = steps.empty?

    # Returns the number of steps in the pipeline.
    #
    # @return [Integer] Number of steps
    def length = steps.length

    # Alias for {#length}.
    # @see #length
    alias size length

    # Returns a human-readable representation of the pipeline.
    #
    # @return [String] Pipeline representation showing step structure
    #
    # @example
    #   pipeline.inspect
    #   # => "#<Pipeline [call(:search) -> select -> call(:visit)]>"
    def inspect
      step_summary = steps.map do |step|
        case step
        when Step::Call then "call(:#{step.tool_name})"
        when Step::Transform then step.operation.to_s
        end
      end.join(" -> ")

      "#<Pipeline [#{step_summary}]>"
    end

    # @!endgroup

    private

    # Adds a step and returns a new pipeline (immutability).
    #
    # @param step [Step::Call, Step::Transform] Step to add
    # @return [Pipeline] New pipeline with step appended
    # @api private
    def add_step(step)
      self.class.new(steps: steps + [step])
    end

    # Infers input specification from the pipeline's first Call step.
    #
    # @return [Hash] Input specification for as_tool
    # @api private
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
