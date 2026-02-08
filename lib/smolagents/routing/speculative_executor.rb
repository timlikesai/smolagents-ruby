module Smolagents
  module Routing
    # Pre-flight feasibility analyzer for speculative tool calls.
    #
    # Analyzes predictions from dispatcher models before committing
    # resources to execution. Checks tool existence, argument validity,
    # budget availability, and confidence thresholds.
    #
    # @example Basic analysis
    #   executor = SpeculativeExecutor.new(tools: { "search" => search_tool })
    #   result = executor.analyze(prediction)
    #   if result.executable?
    #     execute_tool(result.prediction.tool_call)
    #   end
    #
    # @example With budget tracking
    #   executor = SpeculativeExecutor.new(
    #     tools: tools,
    #     budget: TokenMeter.new(budget: 1000, used: 800)
    #   )
    #   result = executor.analyze(prediction)
    #   result.infeasible? if result.estimated_cost > budget.remaining
    #
    # @example Batch analysis
    #   results = executor.analyze_batch(predictions)
    #   best = executor.best_executable(predictions)
    #
    class SpeculativeExecutor
      # Minimum confidence to avoid "very low confidence" warning
      LOW_CONFIDENCE_THRESHOLD = 0.3

      attr_reader :tools, :capabilities, :budget

      # @param tools [Hash<String, Tool>] Available tools by name
      # @param capabilities [ServerCapability, nil] Model capabilities (optional)
      # @param budget [TokenMeter, nil] Remaining budget (optional)
      def initialize(tools:, capabilities: nil, budget: nil)
        @tools = tools.transform_keys(&:to_s)
        @capabilities = capabilities
        @budget = budget
      end

      # Analyze a prediction for feasibility.
      #
      # @param prediction [SpeculativeToolCall] The prediction to analyze
      # @return [SpeculationResult] Feasibility analysis result
      def analyze(prediction)
        tool = tools[prediction.tool_call.name]
        return unknown_tool_result(prediction) unless tool

        reasons = collect_reasons(tool, prediction)
        cost = estimate_execution_cost(prediction)
        determine_feasibility(prediction, reasons, cost)
      end

      # Batch analyze multiple predictions.
      #
      # @param predictions [Array<SpeculativeToolCall>] Predictions to analyze
      # @return [Array<SpeculationResult>] Analysis results
      def analyze_batch(predictions)
        predictions.map { |p| analyze(p) }
      end

      # Find the best executable prediction from a batch.
      #
      # @param predictions [Array<SpeculativeToolCall>] Predictions to analyze
      # @return [SpeculationResult, nil] Highest confidence executable, or nil
      def best_executable(predictions)
        results = analyze_batch(predictions)
        executables = results.select(&:executable?)
        executables.max_by(&:confidence)
      end

      private

      def collect_reasons(tool, prediction)
        reasons = validate_arguments(tool, prediction.tool_call.arguments)
        reasons << budget_reason(prediction) if budget_issue?(prediction)
        reasons << confidence_reason(prediction) if low_confidence?(prediction)
        reasons
      end

      def validate_arguments(tool, arguments)
        missing_args(tool, arguments).map { |arg| "Missing required argument: #{arg}" }
      end

      def missing_args(tool, arguments) = extract_required_args(tool) - arguments.keys.map(&:to_s)

      def extract_required_args(tool)
        return [] unless tool.respond_to?(:inputs) && tool.inputs

        tool.inputs.reject { |_, spec| spec[:required] == false }.keys.map(&:to_s)
      end

      def estimate_execution_cost(prediction)
        base = 50
        arg_cost = prediction.tool_call.arguments.values.sum { |v| (v.to_s.length / 4.0).ceil }
        base + arg_cost
      end

      def budget_issue?(prediction) = budget && estimate_execution_cost(prediction) > budget.remaining

      def budget_reason(prediction)
        cost = estimate_execution_cost(prediction)
        "Insufficient budget (need #{cost}, have #{budget.remaining})"
      end

      def low_confidence?(prediction) = prediction.confidence < LOW_CONFIDENCE_THRESHOLD

      def confidence_reason(prediction) = "Very low confidence (#{prediction.confidence.round(2)})"

      def unknown_tool_result(prediction)
        Types::SpeculationResult.infeasible(
          prediction:,
          reasons: ["Unknown tool: #{prediction.tool_call.name}"]
        )
      end

      def determine_feasibility(prediction, reasons, cost)
        return Types::SpeculationResult.executable(prediction:, cost:) if reasons.empty?
        return Types::SpeculationResult.infeasible(prediction:, reasons:) if blocking_reason?(reasons)

        Types::SpeculationResult.uncertain(prediction:, reasons:, cost:)
      end

      def blocking_reason?(reasons)
        reasons.any? { |r| r.start_with?("Unknown tool", "Missing required") }
      end
    end
  end
end
