require "spec_helper"

RSpec.describe Smolagents::Builders::MixtureOfAgentsBuilder do
  include_context "with mocked tools"
  include_context "with mocked model"

  let(:builder) { described_class.create }
  let(:method_name) { :proposers }
  let(:method_args) { [3] }

  let(:chain_methods) do
    [
      [:proposers, [3]],
      [:strategy, [:voting]]
    ]
  end

  it_behaves_like "an immutable builder"
  it_behaves_like "a chainable builder"

  describe "fluent method chaining" do
    it "returns the same builder class for each chained method" do
      result = builder.model { mock_model }.proposers(3).strategy(:voting)
      expect(result).to be_a(described_class)
    end

    it "preserves configuration through the chain" do
      final_builder = builder
                      .model { mock_model }
                      .proposers(3)
                      .strategy(:synthesis)
                      .timeout(per_proposer: 45)

      expect(final_builder.config[:model_block]).to be_a(Proc)
      expect(final_builder.config[:proposer_count]).to eq(3)
      expect(final_builder.config[:aggregation_strategy]).to eq(:synthesis)
      expect(final_builder.config[:timeout_per_proposer]).to eq(45)
    end

    it "returns a new instance for each method call (immutability)" do
      b1 = builder
      b2 = b1.proposers(3)
      b3 = b2.strategy(:synthesis)

      expect([b1, b2, b3].uniq.size).to eq(3)
    end

    it "does not mutate previous builder instances" do
      original_config = builder.config.dup
      builder.proposers(3).strategy(:synthesis)
      expect(builder.config).to eq(original_config)
    end
  end

  describe ".create" do
    it "creates a new builder with default configuration" do
      builder = described_class.create

      expect(builder).to be_a(described_class)
      expect(builder.config[:aggregation_strategy]).to eq(:voting)
      expect(builder.config[:timeout_per_proposer]).to eq(30)
      expect(builder.config[:parallel]).to be true
    end

    it "has nil model_block by default" do
      expect(builder.config[:model_block]).to be_nil
    end

    it "has nil proposer_count by default" do
      expect(builder.config[:proposer_count]).to be_nil
    end
  end

  describe "#model" do
    it "stores the model block" do
      result = builder.model { mock_model }

      expect(result.config[:model_block]).to be_a(Proc)
    end

    it "defers model creation until build time" do
      call_count = 0
      result = builder.model do
        call_count += 1
        mock_model
      end

      expect(call_count).to eq(0)
      result.config[:model_block].call
      expect(call_count).to eq(1)
    end

    it "is immutable - returns new builder" do
      builder1 = described_class.create
      builder2 = builder1.model { mock_model }

      expect(builder1.config[:model_block]).to be_nil
      expect(builder2.config[:model_block]).not_to be_nil
    end
  end

  describe "#proposers" do
    it "sets proposer count" do
      result = builder.proposers(5)

      expect(result.config[:proposer_count]).to eq(5)
    end

    it "stores optional customization block" do
      result = builder.proposers(3) { |b, idx| b.persona("Expert #{idx}") }

      expect(result.config[:proposer_block]).to be_a(Proc)
    end

    it "validates minimum proposer count (2)" do
      expect { builder.proposers(1) }.to raise_error(ArgumentError)
    end

    it "validates maximum proposer count (20)" do
      expect { builder.proposers(21) }.to raise_error(ArgumentError)
    end

    it "accepts valid proposer counts" do
      (2..20).each do |count|
        expect { builder.proposers(count) }.not_to raise_error
      end
    end

    it "is immutable - returns new builder" do
      builder1 = described_class.create
      builder2 = builder1.proposers(3)

      expect(builder1.config[:proposer_count]).to be_nil
      expect(builder2.config[:proposer_count]).to eq(3)
    end
  end

  describe "#aggregator" do
    it "stores the aggregator block" do
      result = builder.aggregator { |b| b.persona("Synthesizer") }

      expect(result.config[:aggregator_block]).to be_a(Proc)
    end

    it "is immutable - returns new builder" do
      builder1 = described_class.create
      builder2 = builder1.aggregator { |b| b }

      expect(builder1.config[:aggregator_block]).to be_nil
      expect(builder2.config[:aggregator_block]).not_to be_nil
    end
  end

  describe "#strategy" do
    it "sets :voting strategy" do
      result = builder.strategy(:voting)

      expect(result.config[:aggregation_strategy]).to eq(:voting)
    end

    it "sets :synthesis strategy" do
      result = builder.strategy(:synthesis)

      expect(result.config[:aggregation_strategy]).to eq(:synthesis)
    end

    it "sets :rank_fusion strategy" do
      result = builder.strategy(:rank_fusion)

      expect(result.config[:aggregation_strategy]).to eq(:rank_fusion)
    end

    it "rejects invalid strategies" do
      expect { builder.strategy(:invalid) }.to raise_error(ArgumentError, /Invalid strategy/)
    end

    it "is immutable - returns new builder" do
      builder1 = described_class.create
      builder2 = builder1.strategy(:synthesis)

      expect(builder1.config[:aggregation_strategy]).to eq(:voting)
      expect(builder2.config[:aggregation_strategy]).to eq(:synthesis)
    end
  end

  describe "#timeout" do
    it "sets timeout per proposer" do
      result = builder.timeout(per_proposer: 60)

      expect(result.config[:timeout_per_proposer]).to eq(60)
    end

    it "is immutable - returns new builder" do
      builder1 = described_class.create
      builder2 = builder1.timeout(per_proposer: 45)

      expect(builder1.config[:timeout_per_proposer]).to eq(30)
      expect(builder2.config[:timeout_per_proposer]).to eq(45)
    end
  end

  describe "#parallel" do
    it "enables parallel execution by default" do
      result = builder.parallel

      expect(result.config[:parallel]).to be true
    end

    it "disables parallel execution when set to false" do
      result = builder.parallel(enabled: false)

      expect(result.config[:parallel]).to be false
    end

    it "is immutable - returns new builder" do
      builder1 = described_class.create.parallel(enabled: false)
      builder2 = builder1.parallel(enabled: true)

      expect(builder1.config[:parallel]).to be false
      expect(builder2.config[:parallel]).to be true
    end
  end

  describe "#on" do
    it "registers event handlers" do
      handler_block = proc { |e| e }
      result = builder.on(:proposer_launched, &handler_block)

      expect(result.config[:handlers].size).to eq(1)
      expect(result.config[:handlers].first[0]).to eq(:proposer_launched)
    end

    it "accumulates multiple handlers" do
      result = builder
               .on(:proposer_launched) { |e| e }
               .on(:proposal_received) { |e| e }
               .on(:aggregation_completed) { |e| e }

      expect(result.config[:handlers].size).to eq(3)
    end

    it "is immutable - returns new builder" do
      builder1 = described_class.create
      builder2 = builder1.on(:step_complete) { |e| e }

      expect(builder1.config[:handlers]).to be_empty
      expect(builder2.config[:handlers].size).to eq(1)
    end
  end

  describe "#build" do
    let(:valid_builder) do
      builder.model { mock_model }.proposers(3)
    end

    it "creates a MoACoordinator" do
      coordinator = valid_builder.build

      expect(coordinator).to be_a(Smolagents::Builders::MoACoordinator)
    end

    it "requires a model" do
      incomplete_builder = builder.proposers(3)

      expect { incomplete_builder.build }.to raise_error(ArgumentError, /Model is required/)
    end

    it "requires proposers" do
      incomplete_builder = builder.model { mock_model }

      expect { incomplete_builder.build }.to raise_error(ArgumentError, /Proposers required/)
    end

    it "requires aggregator for synthesis strategy" do
      synthesis_builder = builder
                          .model { mock_model }
                          .proposers(3)
                          .strategy(:synthesis)

      expect { synthesis_builder.build }.to raise_error(ArgumentError, /Aggregator required/)
    end

    it "requires aggregator for rank_fusion strategy" do
      rank_fusion_builder = builder
                            .model { mock_model }
                            .proposers(3)
                            .strategy(:rank_fusion)

      expect { rank_fusion_builder.build }.to raise_error(ArgumentError, /Aggregator required/)
    end

    it "does not require aggregator for voting strategy" do
      voting_builder = builder
                       .model { mock_model }
                       .proposers(3)
                       .strategy(:voting)

      expect { voting_builder.build }.not_to raise_error
    end

    it "builds the correct number of proposers" do
      coordinator = valid_builder.build

      expect(coordinator.proposers.size).to eq(3)
    end

    it "builds proposers as agents" do
      coordinator = valid_builder.build

      coordinator.proposers.each do |proposer|
        expect(proposer).to be_a(Smolagents::Agents::Agent)
      end
    end

    it "applies proposer customization block" do
      custom_builder = builder
                       .model { mock_model }
                       .proposers(3) { |b, idx| b.instructions("Expert #{idx}") }

      coordinator = custom_builder.build

      # Proposers should have custom instructions
      coordinator.proposers.each_with_index do |proposer, idx|
        expect(proposer.instance_variable_get(:@custom_instructions)).to include("Expert #{idx}")
      end
    end

    it "builds aggregator when provided" do
      synthesis_builder = builder
                          .model { mock_model }
                          .proposers(3)
                          .strategy(:synthesis)
                          .aggregator { |b| b.instructions("Synthesizer") }

      coordinator = synthesis_builder.build

      expect(coordinator.aggregator).to be_a(Smolagents::Agents::Agent)
    end

    it "does not build aggregator for voting strategy" do
      coordinator = valid_builder.strategy(:voting).build

      expect(coordinator.aggregator).to be_nil
    end

    it "creates MoAConfig with correct values" do
      custom_builder = builder
                       .model { mock_model }
                       .proposers(5)
                       .strategy(:voting)
                       .timeout(per_proposer: 45)
                       .parallel(enabled: false)

      coordinator = custom_builder.build

      expect(coordinator.config.proposer_count).to eq(5)
      expect(coordinator.config.aggregation_strategy).to eq(:voting)
      expect(coordinator.config.timeout_per_proposer).to eq(45)
      expect(coordinator.config.parallel).to be false
    end
  end

  describe "#run" do
    let(:mock_run_result) do
      Smolagents::Types::RunResult.success(output: "test result", steps: [])
    end

    it "builds and runs in one step" do
      mock_coordinator = instance_double(Smolagents::Builders::MoACoordinator)
      allow(Smolagents::Builders::MoACoordinator).to receive(:new).and_return(mock_coordinator)
      allow(mock_coordinator).to receive(:run).and_return(mock_run_result)

      result = builder
               .model { mock_model }
               .proposers(3)
               .run("Test task")

      expect(mock_coordinator).to have_received(:run).with("Test task")
      expect(result).to eq(mock_run_result)
    end
  end

  describe "#inspect" do
    it "shows proposer count and strategy" do
      configured = builder.proposers(5).strategy(:synthesis)

      expect(configured.inspect).to include("MixtureOfAgentsBuilder")
      expect(configured.inspect).to include("proposers=5")
      expect(configured.inspect).to include("strategy=synthesis")
    end

    it "shows unknown proposer count when not set" do
      expect(builder.inspect).to include("proposers=?")
    end
  end

  describe "full configuration example" do
    it "supports complete MoA configuration" do
      coordinator = builder
                    .model { mock_model }
                    .proposers(3) { |b, idx| b.instructions("Expert #{idx + 1}") }
                    .strategy(:synthesis)
                    .aggregator { |b| b.instructions("Synthesize all proposals") }
                    .timeout(per_proposer: 45)
                    .parallel(enabled: true)
                    .build

      expect(coordinator).to be_a(Smolagents::Builders::MoACoordinator)
      expect(coordinator.proposers.size).to eq(3)
      expect(coordinator.aggregator).to be_a(Smolagents::Agents::Agent)
      expect(coordinator.config.timeout_per_proposer).to eq(45)
      expect(coordinator.config.parallel).to be true
    end

    it "supports event handlers via builder" do
      events = []

      # Build with handlers - they'll be registered on coordinator
      configured_builder = builder
                           .model { mock_model }
                           .proposers(3)
                           .on(:proposer_launched) { |e| events << e }
                           .on(:proposal_received) { |e| events << e }

      expect(configured_builder.config[:handlers].size).to eq(2)
    end
  end
end

RSpec.describe Smolagents do
  include_context "with mocked tools"
  include_context "with mocked model"

  describe ".mixture_of_agents" do
    it "returns a MixtureOfAgentsBuilder" do
      builder = described_class.mixture_of_agents

      expect(builder).to be_a(Smolagents::Builders::MixtureOfAgentsBuilder)
    end

    it "can be chained to build a coordinator" do
      coordinator = described_class.mixture_of_agents
                                   .model { mock_model }
                                   .proposers(3)
                                   .build

      expect(coordinator).to be_a(Smolagents::Builders::MoACoordinator)
    end
  end
end
