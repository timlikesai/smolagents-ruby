require "spec_helper"
require "smolagents/context/provider"

RSpec.describe Smolagents::Context::Provider do
  # Minimal implementation for testing required methods
  let(:minimal_provider_class) do
    Class.new do
      include Smolagents::Context::Provider

      def context_key = :minimal
      def context_layer = Smolagents::Context::Layer::STRATEGIC
      def context_contribution(budget:) = "content"
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
      def context_contribution(budget:) = budget > 100 ? "full" : "short"
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

    describe "#context_contribution" do
      it "raises NotImplementedError when not implemented" do
        provider = bare_provider_class.new
        expect do
          provider.context_contribution(budget: 1000)
        end.to raise_error(NotImplementedError,
                           /must implement #context_contribution/)
      end

      it "returns content when implemented" do
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
        def context_contribution(budget:) = "Content for #{@name}"
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
        def context_contribution(budget:) = "parent content"
      end

      child = Class.new(parent) do
        def context_key = :child
        def context_contribution(budget:) = "child content"
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
        def context_contribution(budget:) = nil
      end

      provider = klass.new
      expect(provider.context_contribution(budget: 100)).to be_nil
    end
  end
end
