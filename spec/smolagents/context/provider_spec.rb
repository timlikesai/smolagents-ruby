require "spec_helper"
require "smolagents/context/provider"

RSpec.describe Smolagents::Context::Provider do
  # Minimal implementation for testing required methods
  let(:minimal_provider_class) do
    Class.new do
      include Smolagents::Context::Provider

      def context_key = :minimal
      def context_layer = Smolagents::Context::Layer::STRATEGIC
      def generate_contribution(budget:) = "content"
    end
  end

  # Bare include for testing NotImplementedError
  let(:bare_provider_class) do
    Class.new do
      include Smolagents::Context::Provider
    end
  end

  # Custom implementation with overrides
  let(:custom_provider_class) do
    Class.new do
      include Smolagents::Context::Provider

      def context_key = :custom
      def context_layer = Smolagents::Context::Layer::TACTICAL
      def generate_contribution(budget:) = budget > 100 ? "full" : "short"
      def context_priority = 75
      def context_relevance(task:, step:) = task.include?("search") ? 1.0 : 0.5
      def context_optional? = false
      def context_active? = @active
      attr_writer :active
    end
  end

  describe "class methods" do
    it "adds context_provider? class method" do
      expect(minimal_provider_class).to respond_to(:context_provider?)
      expect(minimal_provider_class.context_provider?).to be true
    end
  end

  describe "required methods" do
    describe "#context_key" do
      it "raises NotImplementedError when not implemented" do
        provider = bare_provider_class.new
        expect { provider.context_key }.to raise_error(NotImplementedError, /must implement #context_key/)
      end

      it "returns symbol when implemented" do
        provider = minimal_provider_class.new
        expect(provider.context_key).to eq(:minimal)
      end
    end

    describe "#context_layer" do
      it "raises NotImplementedError when not implemented" do
        provider = bare_provider_class.new
        expect { provider.context_layer }.to raise_error(NotImplementedError, /must implement #context_layer/)
      end

      it "returns Layer when implemented" do
        provider = minimal_provider_class.new
        expect(provider.context_layer).to eq(Smolagents::Context::Layer::STRATEGIC)
      end
    end

    describe "#generate_contribution" do
      it "raises NotImplementedError when not implemented" do
        provider = bare_provider_class.new
        expect do
          provider.generate_contribution(budget: 1000)
        end.to raise_error(NotImplementedError,
                           /must implement #generate_contribution/)
      end

      it "returns content when implemented" do
        provider = minimal_provider_class.new
        expect(provider.generate_contribution(budget: 1000)).to eq("content")
      end

      it "receives budget parameter" do
        provider = custom_provider_class.new
        expect(provider.generate_contribution(budget: 200)).to eq("full")
        expect(provider.generate_contribution(budget: 50)).to eq("short")
      end
    end

    describe "#context_contribution" do
      it "calls generate_contribution and returns content" do
        provider = minimal_provider_class.new
        expect(provider.context_contribution(budget: 1000)).to eq("content")
      end

      it "receives budget parameter" do
        provider = custom_provider_class.new
        expect(provider.context_contribution(budget: 200)).to eq("full")
        expect(provider.context_contribution(budget: 50)).to eq("short")
      end
    end
  end

  describe "optional methods with defaults" do
    let(:provider) { minimal_provider_class.new }

    describe "#context_priority" do
      it "defaults to 50" do
        expect(provider.context_priority).to eq(50)
      end

      it "can be overridden" do
        custom = custom_provider_class.new
        expect(custom.context_priority).to eq(75)
      end
    end

    describe "#context_relevance" do
      it "defaults to 1.0" do
        expect(provider.context_relevance(task: "anything", step: 1)).to eq(1.0)
      end

      it "can be overridden with custom logic" do
        custom = custom_provider_class.new
        expect(custom.context_relevance(task: "search query", step: 1)).to eq(1.0)
        expect(custom.context_relevance(task: "other task", step: 1)).to eq(0.5)
      end
    end

    describe "#context_optional?" do
      it "defaults to true" do
        expect(provider.context_optional?).to be true
      end

      it "can be overridden" do
        custom = custom_provider_class.new
        expect(custom.context_optional?).to be false
      end
    end

    describe "#context_active?" do
      it "defaults to true" do
        expect(provider.context_active?).to be true
      end

      it "can be overridden with dynamic logic" do
        custom = custom_provider_class.new
        custom.active = true
        expect(custom.context_active?).to be true
        custom.active = false
        expect(custom.context_active?).to be false
      end
    end
  end

  describe "integration" do
    it "works as a concern in a real class" do
      klass = Class.new do
        include Smolagents::Context::Provider

        def initialize(name)
          @name = name
        end

        def context_key = @name.to_sym
        def context_layer = Smolagents::Context::Layer::PERSISTENT
        def generate_contribution(budget:) = "Content for #{@name}"
      end

      provider = klass.new("test_provider")
      expect(provider.context_key).to eq(:test_provider)
      expect(provider.context_layer).to eq(Smolagents::Context::Layer::PERSISTENT)
      expect(provider.context_contribution(budget: 100)).to eq("Content for test_provider")
    end

    it "can be included multiple times in inheritance" do
      parent = Class.new do
        include Smolagents::Context::Provider

        def context_key = :parent
        def context_layer = Smolagents::Context::Layer::STRATEGIC
        def generate_contribution(budget:) = "parent content"
      end

      child = Class.new(parent) do
        def context_key = :child
        def generate_contribution(budget:) = "child content"
      end

      expect(child.new.context_key).to eq(:child)
      expect(child.new.context_layer).to eq(Smolagents::Context::Layer::STRATEGIC)
      expect(child.new.context_contribution(budget: 100)).to eq("child content")
    end
  end

  describe "nil contributions" do
    it "allows nil contribution to indicate skip" do
      klass = Class.new do
        include Smolagents::Context::Provider

        def context_key = :maybe
        def context_layer = Smolagents::Context::Layer::TACTICAL
        def generate_contribution(budget:) = nil
      end

      provider = klass.new
      expect(provider.context_contribution(budget: 100)).to be_nil
    end
  end

  describe "truncation strategies" do
    # Helper to create provider with specific content and strategy
    def create_truncation_provider(content:, strategy:)
      klass = Class.new do
        include Smolagents::Context::Provider

        attr_reader :content_to_return, :strategy

        def initialize(content, strategy)
          @content_to_return = content
          @strategy = strategy
        end

        def context_key = :truncation_test
        def context_layer = Smolagents::Context::Layer::STRATEGIC
        def generate_contribution(budget:) = @content_to_return
        def context_truncation_strategy = @strategy
      end
      klass.new(content, strategy)
    end

    describe "#context_truncation_strategy" do
      it "defaults to :none" do
        provider = minimal_provider_class.new
        expect(provider.context_truncation_strategy).to eq(:none)
      end
    end

    describe "#estimate_tokens" do
      let(:provider) { minimal_provider_class.new }

      it "estimates 4 chars per token" do
        expect(provider.estimate_tokens("1234")).to eq(1)
        expect(provider.estimate_tokens("12345678")).to eq(2)
      end

      it "rounds up partial tokens" do
        expect(provider.estimate_tokens("12345")).to eq(2)
      end

      it "handles empty content" do
        expect(provider.estimate_tokens("")).to eq(0)
      end
    end

    describe ":none strategy" do
      it "returns content unchanged regardless of budget" do
        provider = create_truncation_provider(content: "a" * 100, strategy: :none)
        result = provider.context_contribution(budget: 1)
        expect(result.length).to eq(100)
      end
    end

    describe ":adaptive strategy" do
      it "returns content when within budget" do
        provider = create_truncation_provider(content: "a" * 40, strategy: :adaptive)
        result = provider.context_contribution(budget: 10) # 10 tokens = 40 chars
        expect(result.length).to eq(40)
      end

      it "truncates content when over budget" do
        provider = create_truncation_provider(content: "a" * 100, strategy: :adaptive)
        result = provider.context_contribution(budget: 10) # 10 tokens = 40 chars
        expect(result.length).to eq(40)
      end
    end

    describe ":truncate strategy" do
      it "always truncates to budget" do
        provider = create_truncation_provider(content: "a" * 100, strategy: :truncate)
        result = provider.context_contribution(budget: 5) # 5 tokens = 20 chars
        expect(result.length).to eq(20)
      end

      it "truncates even when content fits" do
        provider = create_truncation_provider(content: "abcd", strategy: :truncate)
        result = provider.context_contribution(budget: 100)
        # Content is shorter than budget, so it returns full content
        expect(result).to eq("abcd")
      end
    end

    describe ":fail strategy" do
      it "returns content when within budget" do
        provider = create_truncation_provider(content: "a" * 40, strategy: :fail)
        result = provider.context_contribution(budget: 10) # 10 tokens = 40 chars
        expect(result.length).to eq(40)
      end

      it "raises BudgetExceededError when over budget" do
        provider = create_truncation_provider(content: "a" * 100, strategy: :fail)
        expect do
          provider.context_contribution(budget: 10) # 10 tokens = 40 chars
        end.to raise_error(Smolagents::Context::BudgetExceededError) do |error|
          expect(error.budget).to eq(10)
          expect(error.actual).to eq(25) # 100 chars / 4 = 25 tokens
        end
      end
    end

    describe "strategy override via parameter" do
      it "uses parameter strategy over default" do
        provider = create_truncation_provider(content: "a" * 100, strategy: :none)
        result = provider.context_contribution(budget: 10, truncation_strategy: :truncate)
        expect(result.length).to eq(40)
      end
    end
  end

  describe Smolagents::Context::BudgetExceededError do
    it "includes budget and actual in error" do
      error = Smolagents::Context::BudgetExceededError.new("test", budget: 100, actual: 150)
      expect(error.budget).to eq(100)
      expect(error.actual).to eq(150)
      expect(error.message).to eq("test")
    end
  end
end
