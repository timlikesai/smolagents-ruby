require "smolagents"

RSpec.describe Smolagents::Types::ContextScope do
  describe ".create" do
    it "defaults to :task_only" do
      scope = described_class.create

      expect(scope.level).to eq(:task_only)
      expect(scope.task_only?).to be true
    end

    it "accepts valid scope levels" do
      %i[task_only observations summary full].each do |level|
        scope = described_class.create(level)
        expect(scope.level).to eq(level)
      end
    end

    it "converts string levels to symbols" do
      scope = described_class.create("observations")

      expect(scope.level).to eq(:observations)
    end

    it "raises ArgumentError for invalid level" do
      expect { described_class.create(:invalid) }
        .to raise_error(ArgumentError, /Invalid scope: invalid/)
    end

    it "includes valid levels in error message" do
      expect { described_class.create(:bad) }
        .to raise_error(ArgumentError, /Use: task_only, observations, summary, full/)
    end
  end

  describe "level predicates" do
    it "#task_only? returns true only for task_only scope" do
      expect(described_class.create(:task_only).task_only?).to be true
      expect(described_class.create(:observations).task_only?).to be false
      expect(described_class.create(:summary).task_only?).to be false
      expect(described_class.create(:full).task_only?).to be false
    end

    it "#observations? returns true only for observations scope" do
      expect(described_class.create(:task_only).observations?).to be false
      expect(described_class.create(:observations).observations?).to be true
      expect(described_class.create(:summary).observations?).to be false
      expect(described_class.create(:full).observations?).to be false
    end

    it "#summary? returns true only for summary scope" do
      expect(described_class.create(:task_only).summary?).to be false
      expect(described_class.create(:observations).summary?).to be false
      expect(described_class.create(:summary).summary?).to be true
      expect(described_class.create(:full).summary?).to be false
    end

    it "#full? returns true only for full scope" do
      expect(described_class.create(:task_only).full?).to be false
      expect(described_class.create(:observations).full?).to be false
      expect(described_class.create(:summary).full?).to be false
      expect(described_class.create(:full).full?).to be true
    end
  end

  describe "#extract_from" do
    let(:memory) do
      memory = Smolagents::Runtime::AgentMemory.new("You are a helpful assistant.")

      # Add a task
      memory.add_task("Original parent task")

      # Build and add action steps with observations
      step1 = Smolagents::Runtime::ActionStepBuilder.new(step_number: 0)
      step1.observations = "First observation: found data"
      memory << step1.build

      step2 = Smolagents::Runtime::ActionStepBuilder.new(step_number: 1)
      step2.observations = "Second observation: processed data"
      memory << step2.build

      memory
    end

    describe "with :task_only scope" do
      let(:scope) { described_class.create(:task_only) }

      it "returns only task and inherited scope" do
        result = scope.extract_from(memory, task: "Sub task")

        expect(result).to eq(task: "Sub task", inherited_scope: :task_only)
      end

      it "does not include parent context" do
        result = scope.extract_from(memory, task: "Sub task")

        expect(result.key?(:parent_observations)).to be false
        expect(result.key?(:parent_summary)).to be false
        expect(result.key?(:parent_memory)).to be false
      end
    end

    describe "with :observations scope" do
      let(:scope) { described_class.create(:observations) }

      it "returns task with parent observations" do
        result = scope.extract_from(memory, task: "Sub task")

        expect(result[:task]).to eq("Sub task")
        expect(result[:inherited_scope]).to eq(:observations)
        expect(result[:parent_observations]).to include("First observation")
        expect(result[:parent_observations]).to include("Second observation")
      end

      it "joins observations with separator" do
        result = scope.extract_from(memory, task: "Sub task")

        expect(result[:parent_observations]).to include("---")
      end
    end

    describe "with :summary scope" do
      let(:scope) { described_class.create(:summary) }

      it "returns task with summarized context" do
        result = scope.extract_from(memory, task: "Sub task")

        expect(result[:task]).to eq("Sub task")
        expect(result[:inherited_scope]).to eq(:summary)
        expect(result[:parent_summary]).to be_a(String)
      end

      it "includes system prompt in summary" do
        result = scope.extract_from(memory, task: "Sub task")

        expect(result[:parent_summary]).to include("helpful assistant")
      end
    end

    describe "with :full scope" do
      let(:scope) { described_class.create(:full) }

      it "returns task with full parent memory" do
        result = scope.extract_from(memory, task: "Sub task")

        expect(result[:task]).to eq("Sub task")
        expect(result[:inherited_scope]).to eq(:full)
        expect(result[:parent_memory]).to be_an(Array)
      end

      it "includes all messages from memory" do
        result = scope.extract_from(memory, task: "Sub task")

        # Should have system message + task + action steps
        expect(result[:parent_memory].length).to be >= 3
      end

      it "returns ChatMessage objects" do
        result = scope.extract_from(memory, task: "Sub task")

        expect(result[:parent_memory]).to all(respond_to(:role).and(respond_to(:content)))
      end
    end
  end

  describe "CONTEXT_SCOPE_LEVELS constant" do
    it "defines all valid levels in order" do
      expect(Smolagents::Types::CONTEXT_SCOPE_LEVELS).to eq(%i[task_only observations summary full])
    end

    it "is frozen" do
      expect(Smolagents::Types::CONTEXT_SCOPE_LEVELS.frozen?).to be true
    end
  end

  describe "immutability" do
    it "is frozen (Data.define)" do
      scope = described_class.create(:observations)

      expect(scope.frozen?).to be true
    end

    it "level cannot be modified" do
      scope = described_class.create(:task_only)

      expect { scope.level = :full }.to raise_error(NoMethodError)
    end
  end

  describe "pattern matching" do
    it "supports pattern matching on level" do
      scope = described_class.create(:observations)

      # rubocop:disable RSpec/DescribedClass -- pattern matching requires actual class constant
      result = case scope
               in Smolagents::Types::ContextScope[level: :task_only] then :minimal
               in Smolagents::Types::ContextScope[level: :observations] then :moderate
               in Smolagents::Types::ContextScope[level: :summary] then :balanced
               in Smolagents::Types::ContextScope[level: :full] then :maximum
               end
      # rubocop:enable RSpec/DescribedClass

      expect(result).to eq(:moderate)
    end
  end
end
