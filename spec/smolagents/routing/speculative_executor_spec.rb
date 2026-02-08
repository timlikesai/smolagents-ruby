require "spec_helper"

RSpec.describe Smolagents::Routing::SpeculativeExecutor do
  let(:search_tool) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "search"
      self.description = "Search for things"
      self.inputs = { query: { type: "string", description: "Search query" } }
      self.output_type = "string"
      def execute(query:) = "results for #{query}"
    end.new
  end

  let(:calculator_tool) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "calculator"
      self.description = "Calculate expressions"
      self.inputs = {
        expression: { type: "string", description: "Math expression" },
        precision: { type: "integer", description: "Decimal places", required: false }
      }
      self.output_type = "number"
      def execute(expression:, precision: 2) = expression.to_f.round(precision)
    end.new
  end

  let(:tools) { { "search" => search_tool, "calculator" => calculator_tool } }

  def make_prediction(name:, arguments:, confidence: 0.85)
    tool_call = Smolagents::Types::ToolCall.new(name:, arguments:, id: "tc_1")
    Smolagents::Types::SpeculativeToolCall.from_function_gemma(tool_call, confidence:)
  end

  describe "initialization" do
    it "accepts tools hash" do
      executor = described_class.new(tools:)

      expect(executor.tools).to eq({ "search" => search_tool, "calculator" => calculator_tool })
    end

    it "normalizes tool keys to strings" do
      executor = described_class.new(tools: { search: search_tool })

      expect(executor.tools.keys).to eq(["search"])
    end

    it "accepts optional capabilities" do
      capability = Smolagents::Types::ServerCapability.unknown
      executor = described_class.new(tools:, capabilities: capability)

      expect(executor.capabilities).to eq(capability)
    end

    it "accepts optional budget" do
      budget = Smolagents::Context::TokenMeter.new(budget: 1000)
      executor = described_class.new(tools:, budget:)

      expect(executor.budget).to eq(budget)
    end
  end

  describe "#analyze" do
    subject(:executor) { described_class.new(tools:) }

    context "with valid tool call" do
      it "returns executable for valid tool with all required args" do
        prediction = make_prediction(name: "search", arguments: { "query" => "Ruby" })
        result = executor.analyze(prediction)

        expect(result).to be_executable
        expect(result.feasibility_reasons).to be_empty
        expect(result.should_execute?).to be true
      end

      it "includes estimated cost" do
        prediction = make_prediction(name: "search", arguments: { "query" => "Ruby" })
        result = executor.analyze(prediction)

        expect(result.estimated_cost).to be_a(Integer)
        expect(result.estimated_cost).to be > 0
      end

      it "accepts optional arguments" do
        prediction = make_prediction(
          name: "calculator",
          arguments: { "expression" => "2+2" }
        )
        result = executor.analyze(prediction)

        expect(result).to be_executable
      end
    end

    context "with unknown tool" do
      it "returns infeasible" do
        prediction = make_prediction(name: "nonexistent", arguments: {})
        result = executor.analyze(prediction)

        expect(result).to be_infeasible
        expect(result.feasibility_reasons).to include("Unknown tool: nonexistent")
        expect(result.should_delegate?).to be true
      end

      it "does not check arguments for unknown tools" do
        prediction = make_prediction(name: "unknown", arguments: { "random" => "stuff" })
        result = executor.analyze(prediction)

        expect(result.feasibility_reasons.size).to eq(1)
        expect(result.feasibility_reasons.first).to start_with("Unknown tool")
      end
    end

    context "with missing required arguments" do
      it "returns infeasible for missing required arg" do
        prediction = make_prediction(name: "search", arguments: {})
        result = executor.analyze(prediction)

        expect(result).to be_infeasible
        expect(result.feasibility_reasons).to include("Missing required argument: query")
      end

      it "reports multiple missing args" do
        # Create tool with multiple required args
        multi_arg_tool = Class.new(Smolagents::Tool) do
          self.tool_name = "multi"
          self.description = "Multi-arg tool"
          self.inputs = {
            first: { type: "string", description: "First" },
            second: { type: "string", description: "Second" }
          }
          self.output_type = "string"
          def execute(first:, second:) = "#{first} #{second}"
        end.new

        executor = described_class.new(tools: { "multi" => multi_arg_tool })
        prediction = make_prediction(name: "multi", arguments: {})
        result = executor.analyze(prediction)

        expect(result).to be_infeasible
        expect(result.feasibility_reasons).to include("Missing required argument: first")
        expect(result.feasibility_reasons).to include("Missing required argument: second")
      end
    end

    context "with budget constraints" do
      it "returns uncertain when budget is insufficient" do
        budget = Smolagents::Context::TokenMeter.new(budget: 100, used: 90)
        executor = described_class.new(tools:, budget:)

        prediction = make_prediction(name: "search", arguments: { "query" => "Ruby" })
        result = executor.analyze(prediction)

        expect(result).to be_uncertain
        expect(result.feasibility_reasons.any? { |r| r.include?("Insufficient budget") }).to be true
      end

      it "returns executable when budget is sufficient" do
        budget = Smolagents::Context::TokenMeter.new(budget: 1000, used: 0)
        executor = described_class.new(tools:, budget:)

        prediction = make_prediction(name: "search", arguments: { "query" => "Ruby" })
        result = executor.analyze(prediction)

        expect(result).to be_executable
      end
    end

    context "with low confidence" do
      it "returns uncertain for very low confidence" do
        prediction = make_prediction(name: "search", arguments: { "query" => "Ruby" }, confidence: 0.2)
        result = executor.analyze(prediction)

        expect(result).to be_uncertain
        expect(result.feasibility_reasons.any? { |r| r.include?("Very low confidence") }).to be true
      end

      it "accepts confidence at threshold" do
        prediction = make_prediction(name: "search", arguments: { "query" => "Ruby" }, confidence: 0.3)
        result = executor.analyze(prediction)

        expect(result).to be_executable
      end
    end

    context "with multiple issues" do
      it "returns infeasible if any blocking reason present" do
        budget = Smolagents::Context::TokenMeter.new(budget: 100, used: 90)
        executor = described_class.new(tools:, budget:)

        # Missing required arg is blocking
        prediction = make_prediction(name: "search", arguments: {}, confidence: 0.2)
        result = executor.analyze(prediction)

        expect(result).to be_infeasible
        expect(result.feasibility_reasons.size).to be > 1
      end
    end
  end

  describe "#analyze_batch" do
    subject(:executor) { described_class.new(tools:) }

    it "analyzes multiple predictions" do
      predictions = [
        make_prediction(name: "search", arguments: { "query" => "Ruby" }),
        make_prediction(name: "calculator", arguments: { "expression" => "2+2" }),
        make_prediction(name: "unknown", arguments: {})
      ]

      results = executor.analyze_batch(predictions)

      expect(results.size).to eq(3)
      expect(results[0]).to be_executable
      expect(results[1]).to be_executable
      expect(results[2]).to be_infeasible
    end

    it "returns empty array for empty input" do
      results = executor.analyze_batch([])

      expect(results).to eq([])
    end
  end

  describe "#best_executable" do
    subject(:executor) { described_class.new(tools:) }

    it "returns highest confidence executable" do
      predictions = [
        make_prediction(name: "search", arguments: { "query" => "Ruby" }, confidence: 0.7),
        make_prediction(name: "search", arguments: { "query" => "Ruby" }, confidence: 0.95),
        make_prediction(name: "search", arguments: { "query" => "Ruby" }, confidence: 0.8)
      ]

      result = executor.best_executable(predictions)

      expect(result).to be_executable
      expect(result.confidence).to eq(0.95)
    end

    it "ignores infeasible predictions" do
      predictions = [
        make_prediction(name: "unknown", arguments: {}, confidence: 0.99),
        make_prediction(name: "search", arguments: { "query" => "Ruby" }, confidence: 0.6)
      ]

      result = executor.best_executable(predictions)

      expect(result).to be_executable
      expect(result.confidence).to eq(0.6)
    end

    it "ignores uncertain predictions" do
      budget = Smolagents::Context::TokenMeter.new(budget: 100, used: 90)
      executor = described_class.new(tools:, budget:)

      predictions = [
        make_prediction(name: "search", arguments: { "query" => "Ruby" }, confidence: 0.95),
        make_prediction(name: "search", arguments: { "query" => "x" }, confidence: 0.8)
      ]

      # Both will be uncertain due to budget
      result = executor.best_executable(predictions)

      expect(result).to be_nil
    end

    it "returns nil when no executables" do
      predictions = [
        make_prediction(name: "unknown", arguments: {}),
        make_prediction(name: "search", arguments: {}) # missing required arg
      ]

      result = executor.best_executable(predictions)

      expect(result).to be_nil
    end

    it "returns nil for empty input" do
      result = executor.best_executable([])

      expect(result).to be_nil
    end
  end

  describe "cost estimation" do
    subject(:executor) { described_class.new(tools:) }

    it "estimates higher cost for longer arguments" do
      short_args = make_prediction(name: "search", arguments: { "query" => "x" })
      long_args = make_prediction(name: "search", arguments: { "query" => "a" * 100 })

      short_result = executor.analyze(short_args)
      long_result = executor.analyze(long_args)

      expect(long_result.estimated_cost).to be > short_result.estimated_cost
    end

    it "includes base cost" do
      prediction = make_prediction(name: "search", arguments: { "query" => "" })
      result = executor.analyze(prediction)

      expect(result.estimated_cost).to be >= 50
    end
  end

  describe "without optional dependencies" do
    it "works without budget" do
      executor = described_class.new(tools:)
      prediction = make_prediction(name: "search", arguments: { "query" => "Ruby" })
      result = executor.analyze(prediction)

      expect(result).to be_executable
    end

    it "works without capabilities" do
      executor = described_class.new(tools:)
      prediction = make_prediction(name: "search", arguments: { "query" => "Ruby" })
      result = executor.analyze(prediction)

      expect(result).to be_executable
    end
  end
end
