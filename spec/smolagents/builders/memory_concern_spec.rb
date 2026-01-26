require "spec_helper"

RSpec.describe Smolagents::Builders::MemoryConcern do
  let(:test_builder_class) do
    Class.new(Data.define(:configuration)) do
      include Smolagents::Builders::MemoryConcern

      def self.create
        new(configuration: {})
      end

      def with_config(new_config)
        self.class.new(configuration: configuration.merge(new_config))
      end

      def check_frozen!
        raise FrozenError if configuration[:__frozen__]
      end

      def freeze!
        with_config(__frozen__: true)
      end
    end
  end

  let(:builder) { test_builder_class.create }

  describe "#memory" do
    context "with no arguments" do
      it "creates default memory config" do
        result = builder.memory

        expect(result.configuration[:memory_config]).to be_a(Smolagents::Types::MemoryConfig)
        expect(result.configuration[:memory_config].full?).to be true
      end

      it "returns new builder instance" do
        result = builder.memory

        expect(result).not_to equal(builder)
        expect(result).to be_a(test_builder_class)
      end
    end

    context "with integer argument (budget)" do
      it "sets budget directly" do
        result = builder.memory(100_000)

        config = result.configuration[:memory_config]
        expect(config.budget).to eq(100_000)
      end

      it "defaults strategy to :mask when budget is set" do
        result = builder.memory(50_000)

        config = result.configuration[:memory_config]
        expect(config.mask?).to be true
      end

      it "preserves preserve_recent default" do
        result = builder.memory(100_000)

        config = result.configuration[:memory_config]
        expect(config.preserve_recent).to eq(5)
      end

      it "uses mask_placeholder default" do
        result = builder.memory(100_000)

        config = result.configuration[:memory_config]
        expect(config.mask_placeholder).to eq("[Previous observation truncated]")
      end
    end

    context "with symbol argument (strategy)" do
      it "sets strategy directly" do
        result = builder.memory(:mask)

        config = result.configuration[:memory_config]
        expect(config.mask?).to be true
      end

      it "supports all strategy types" do
        strategies = %i[full mask summarize hybrid]

        strategies.each do |strategy|
          result = builder.memory(strategy)
          config = result.configuration[:memory_config]

          expect(config.strategy).to eq(strategy)
        end
      end

      it "defaults budget to nil when using strategy only" do
        result = builder.memory(:summarize)

        config = result.configuration[:memory_config]
        expect(config.budget).to be_nil
      end
    end

    context "with keyword arguments" do
      it "sets budget with budget:" do
        result = builder.memory(budget: 75_000)

        config = result.configuration[:memory_config]
        expect(config.budget).to eq(75_000)
      end

      it "sets strategy with strategy:" do
        result = builder.memory(strategy: :hybrid)

        config = result.configuration[:memory_config]
        expect(config.hybrid?).to be true
      end

      it "sets preserve_recent with preserve_recent: when budget or strategy provided" do
        # preserve_recent is only used when budget or strategy is set
        result = builder.memory(budget: 50_000, preserve_recent: 10)

        config = result.configuration[:memory_config]
        expect(config.preserve_recent).to eq(10)
      end

      it "combines multiple keyword arguments" do
        result = builder.memory(budget: 50_000, strategy: :mask, preserve_recent: 3)

        config = result.configuration[:memory_config]
        expect(config.budget).to eq(50_000)
        expect(config.mask?).to be true
        expect(config.preserve_recent).to eq(3)
      end

      it "positional args are resolved by type dispatch" do
        # Positional Integer is resolved as budget via dispatch_by_type
        result = builder.memory(100_000)

        config = result.configuration[:memory_config]
        expect(config.budget).to eq(100_000)
      end
    end

    context "strategy behavior" do
      it "full strategy preserves all memory" do
        result = builder.memory(:full)

        config = result.configuration[:memory_config]
        expect(config.full?).to be true
      end

      it "mask strategy truncates observations" do
        result = builder.memory(:mask)

        config = result.configuration[:memory_config]
        expect(config.mask?).to be true
      end

      it "summarize strategy summarizes long observations" do
        result = builder.memory(:summarize)

        config = result.configuration[:memory_config]
        expect(config.summarize?).to be true
      end

      it "hybrid strategy combines strategies" do
        result = builder.memory(:hybrid)

        config = result.configuration[:memory_config]
        expect(config.hybrid?).to be true
      end
    end

    context "immutability" do
      it "does not modify original builder" do
        original_config = builder.configuration.dup

        builder.memory(100_000)

        expect(builder.configuration).to eq(original_config)
      end

      it "returns different instances" do
        result1 = builder.memory(100_000)
        result2 = builder.memory(50_000)

        expect(result1).not_to equal(result2)
        expect(result1.configuration[:memory_config].budget).to eq(100_000)
        expect(result2.configuration[:memory_config].budget).to eq(50_000)
      end
    end

    context "chaining" do
      it "can be chained with other builder methods" do
        result = builder
                 .memory(budget: 100_000, strategy: :mask)
                 .memory(budget: 50_000, preserve_recent: 10)

        config = result.configuration[:memory_config]
        # Second call creates new config (not merge)
        expect(config.budget).to eq(50_000)
        expect(config.preserve_recent).to eq(10)
      end

      it "can be called multiple times with different values" do
        r1 = builder.memory(100_000)
        r2 = r1.memory(200_000)

        expect(r1.configuration[:memory_config].budget).to eq(100_000)
        expect(r2.configuration[:memory_config].budget).to eq(200_000)
      end
    end

    context "frozen builder" do
      it "raises FrozenError when frozen" do
        frozen = test_builder_class.create.freeze!

        expect { frozen.memory(100_000) }.to raise_error(FrozenError)
      end
    end

    context "edge cases" do
      it "accepts zero budget" do
        result = builder.memory(0)

        config = result.configuration[:memory_config]
        expect(config.budget).to eq(0)
      end

      it "accepts large budget" do
        result = builder.memory(10_000_000)

        config = result.configuration[:memory_config]
        expect(config.budget).to eq(10_000_000)
      end

      it "accepts preserve_recent of 1 with budget" do
        result = builder.memory(budget: 10_000, preserve_recent: 1)

        config = result.configuration[:memory_config]
        expect(config.preserve_recent).to eq(1)
      end

      it "accepts large preserve_recent with strategy" do
        result = builder.memory(strategy: :mask, preserve_recent: 100)

        config = result.configuration[:memory_config]
        expect(config.preserve_recent).to eq(100)
      end
    end
  end
end
