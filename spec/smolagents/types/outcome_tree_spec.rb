require "smolagents"
require_relative "../../../lib/smolagents/types/outcome_base"
require_relative "../../../lib/smolagents/types/outcome_tree"

RSpec.describe Smolagents::Types::OutcomeTree do
  # NOTE: The PlanOutcome class from outcome_base.rb is used here, which differs
  # from the Outcome module in outcome.rb. We use the Data.define version.
  let(:outcome_class) { Smolagents::Types::PlanOutcome }

  describe "#initialize" do
    it "creates a tree with root outcome from description" do
      tree = described_class.new("Research AI safety")

      expect(tree.root).to be_a(outcome_class)
      expect(tree.root.description).to eq("Research AI safety")
    end

    it "initializes with empty steps and dependencies" do
      tree = described_class.new("Test plan")

      expect(tree.steps).to eq({})
      expect(tree.dependencies).to eq({})
    end

    it "evaluates block in context of tree" do
      step_added = false
      described_class.new("Test") do
        step_added = true if respond_to?(:step)
      end

      expect(step_added).to be true
    end
  end

  describe "#step" do
    it "adds a step to the tree" do
      tree = described_class.new("Plan") do
        step "Find sources"
      end

      expect(tree.steps.keys).to include("find_sources")
      expect(tree.steps["find_sources"].description).to eq("Find sources")
    end

    it "creates outcomes with desired kind" do
      tree = described_class.new("Plan") do
        step "Test step"
      end

      expect(tree.steps["test_step"].kind).to eq(:desired)
    end

    it "assigns agent type when specified via step parameter" do
      tree = described_class.new("Plan") do
        step "Search web", agent: :web_searcher
      end

      # Agent type is stored in the outcome's metadata (nested structure due to Data.define)
      metadata = tree.steps["search_web"].metadata
      # Handle both direct and nested metadata structure
      agent_type = metadata[:agent_type] || metadata.dig(:metadata, :agent_type)
      expect(agent_type).to eq(:web_searcher)
    end

    it "tracks dependencies" do
      tree = described_class.new("Plan") do
        step "Gather data"
        step "Analyze data", depends_on: "Gather data"
      end

      expect(tree.dependencies["analyze_data"]).to eq(["gather_data"])
    end

    it "tracks multiple dependencies" do
      tree = described_class.new("Plan") do
        step "Get A"
        step "Get B"
        step "Combine", depends_on: ["Get A", "Get B"]
      end

      expect(tree.dependencies["combine"]).to contain_exactly("get_a", "get_b")
    end

    it "supports nested steps" do
      tree = described_class.new("Plan") do
        step "Design" do
          step "Choose libraries"
          step "Define models"
        end
      end

      expect(tree.steps.keys).to include("design", "choose_libraries", "define_models")
    end

    it "returns the created step outcome" do
      result = nil
      described_class.new("Plan") do
        result = step("Test step")
      end

      expect(result).to be_a(outcome_class)
      expect(result.description).to eq("Test step")
    end
  end

  describe "#topological_sort" do
    it "returns steps in dependency order" do
      tree = described_class.new("Plan") do
        step "C", depends_on: "B"
        step "B", depends_on: "A"
        step "A"
      end

      order = tree.topological_sort
      expect(order.index("a")).to be < order.index("b")
      expect(order.index("b")).to be < order.index("c")
    end

    it "handles steps without dependencies" do
      tree = described_class.new("Plan") do
        step "Independent A"
        step "Independent B"
      end

      expect(tree.topological_sort).to contain_exactly("independent_a", "independent_b")
    end

    it "detects circular dependencies" do
      tree = described_class.new("Plan") do
        step "A", depends_on: "B"
        step "B", depends_on: "A"
      end

      expect { tree.topological_sort }.to raise_error(/Circular dependency/)
    end

    it "handles complex dependency graphs" do
      tree = described_class.new("Plan") do
        step "D", depends_on: %w[B C]
        step "B", depends_on: "A"
        step "C", depends_on: "A"
        step "A"
      end

      order = tree.topological_sort
      expect(order.index("a")).to be < order.index("b")
      expect(order.index("a")).to be < order.index("c")
      expect(order.index("b")).to be < order.index("d")
      expect(order.index("c")).to be < order.index("d")
    end
  end

  describe "#execute" do
    it "requires a block" do
      tree = described_class.new("Plan") { step "Test" }

      expect { tree.execute }.to raise_error(ArgumentError, /Block required/)
    end

    it "executes steps in topological order" do
      execution_order = []
      tree = described_class.new("Plan") do
        step "B", depends_on: "A"
        step "A"
      end

      tree.execute do |desired, _results|
        execution_order << desired.description
        "done"
      end

      expect(execution_order).to eq(%w[A B])
    end

    it "passes desired outcome and previous results to block" do
      received_desired = nil
      received_results = nil

      tree = described_class.new("Plan") do
        step "First"
        step "Second"
      end

      tree.execute do |desired, results|
        received_desired = desired
        received_results = results
        "value"
      end

      expect(received_desired.description).to eq("Second")
      expect(received_results.keys).to include("first")
    end

    it "records successful outcomes" do
      tree = described_class.new("Plan") do
        step "Test step"
      end

      results = tree.execute { |_d, _r| "success value" }

      expect(results["test_step"].state).to eq(:success)
      expect(results["test_step"].value).to eq("success value")
    end

    it "records error outcomes when block raises" do
      tree = described_class.new("Plan") do
        step "Failing step"
      end

      results = tree.execute { |_d, _r| raise "intentional failure" }

      expect(results["failing_step"].state).to eq(:error)
      expect(results["failing_step"].error).to be_a(RuntimeError)
      expect(results["failing_step"].error.message).to eq("intentional failure")
    end

    it "tracks execution duration" do
      tree = described_class.new("Plan") do
        step "Quick step"
      end

      results = tree.execute { |_d, _r| "done" }

      expect(results["quick_step"].duration).to be_a(Numeric)
      expect(results["quick_step"].duration).to be >= 0
    end

    it "preserves step metadata with agent type in results" do
      tree = described_class.new("Plan") do
        step "Agent step", agent: :web_searcher
      end

      results = tree.execute { |_d, _r| "done" }

      # Handle nested metadata structure (Data.define creates {:metadata => {...}} pattern)
      metadata = results["agent_step"].metadata
      # The execute method passes desired.metadata which is already {:metadata => {...}}
      # So the result has {:metadata => {:metadata => {...}}}
      agent_type = metadata[:agent_type] ||
                   metadata.dig(:metadata, :agent_type) ||
                   metadata.dig(:metadata, :metadata, :agent_type)
      expect(agent_type).to eq(:web_searcher)
    end
  end

  describe "#trace" do
    it "returns string representation of tree" do
      tree = described_class.new("Research project") do
        step "Find sources"
        step "Analyze"
      end

      trace = tree.trace
      expect(trace).to be_a(String)
      expect(trace).to include("Research project")
    end
  end

  describe "#to_h" do
    it "includes description" do
      tree = described_class.new("Test plan")
      expect(tree.to_h[:description]).to eq("Test plan")
    end

    it "includes steps as hashes" do
      tree = described_class.new("Plan") do
        step "Test step"
      end

      expect(tree.to_h[:steps]).to be_a(Hash)
      expect(tree.to_h[:steps]["test_step"]).to be_a(Hash)
    end

    it "includes dependencies" do
      tree = described_class.new("Plan") do
        step "A"
        step "B", depends_on: "A"
      end

      expect(tree.to_h[:dependencies]).to eq("b" => ["a"])
    end

    it "includes execution order" do
      tree = described_class.new("Plan") do
        step "B", depends_on: "A"
        step "A"
      end

      expect(tree.to_h[:execution_order]).to eq(%w[a b])
    end
  end

  describe "edge cases" do
    describe "empty tree" do
      it "handles tree with no steps" do
        tree = described_class.new("Empty plan")

        expect(tree.steps).to be_empty
        expect(tree.topological_sort).to be_empty
        expect(tree.to_h[:steps]).to be_empty
      end

      it "executes with no steps" do
        tree = described_class.new("Empty plan")
        results = tree.execute { |_d, _r| "done" }

        expect(results).to be_empty
      end
    end

    describe "name normalization" do
      it "normalizes step names to lowercase with underscores" do
        tree = described_class.new("Plan") do
          step "Find Recent Papers"
        end

        expect(tree.steps.keys).to include("find_recent_papers")
      end

      it "handles multiple spaces" do
        tree = described_class.new("Plan") do
          step "Step    With    Spaces"
        end

        expect(tree.steps.keys).to include("step_with_spaces")
      end
    end

    describe "deep nesting" do
      it "handles deeply nested steps" do
        tree = described_class.new("Plan") do
          step "Level 1" do
            step "Level 2" do
              step "Level 3" do
                step "Level 4"
              end
            end
          end
        end

        expect(tree.steps.keys).to include("level_1", "level_2", "level_3", "level_4")
      end
    end

    describe "self-dependency detection" do
      it "detects single-step circular dependency" do
        tree = described_class.new("Plan") do
          step "A", depends_on: "A"
        end

        expect { tree.topological_sort }.to raise_error(/Circular dependency/)
      end
    end

    describe "missing dependency" do
      it "handles dependency on non-existent step gracefully" do
        tree = described_class.new("Plan") do
          step "B", depends_on: "A"
        end

        # topological_sort visits dependencies but missing ones are just skipped
        expect { tree.topological_sort }.not_to raise_error
      end
    end
  end

  describe "Outcome.plan class method" do
    it "creates OutcomeTree via Outcome.plan" do
      tree = outcome_class.plan("Test plan") do
        step "First step"
      end

      expect(tree).to be_a(described_class)
      expect(tree.steps.keys).to include("first_step")
    end
  end

  describe "Outcome.from_agent_result class method" do
    it "creates outcome from agent result with success state" do
      timing = Smolagents::Timing.start_now.stop
      token_usage = Smolagents::TokenUsage.new(input_tokens: 100, output_tokens: 50)
      run_result = instance_double(
        Smolagents::RunResult,
        output: "test output",
        state: :success,
        success?: true,
        timing: timing,
        token_usage: token_usage,
        steps: [instance_double(Smolagents::ActionStep)]
      )

      outcome = outcome_class.from_agent_result(run_result)

      expect(outcome.state).to eq(:success)
      expect(outcome.value).to eq("test output")
    end

    it "uses provided desired outcome description" do
      run_result = instance_double(
        Smolagents::RunResult,
        output: "result",
        state: :success,
        success?: true,
        timing: nil,
        token_usage: nil,
        steps: []
      )
      desired = outcome_class.desired("Custom description")

      outcome = outcome_class.from_agent_result(run_result, desired: desired)

      expect(outcome.description).to eq("Custom description")
    end

    it "handles max_steps_reached state" do
      run_result = instance_double(
        Smolagents::RunResult,
        output: nil,
        state: :max_steps_reached,
        success?: false,
        timing: nil,
        token_usage: nil,
        steps: []
      )

      outcome = outcome_class.from_agent_result(run_result)

      expect(outcome.state).to eq(:partial)
    end

    it "handles error state" do
      run_result = instance_double(
        Smolagents::RunResult,
        output: nil,
        state: :error,
        success?: false,
        timing: nil,
        token_usage: nil,
        steps: []
      )

      outcome = outcome_class.from_agent_result(run_result)

      expect(outcome.state).to eq(:error)
    end
  end
end
