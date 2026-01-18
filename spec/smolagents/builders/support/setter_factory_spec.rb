RSpec.describe Smolagents::Builders::Support::SetterFactory do
  describe ".define_setters (mutable)" do
    let(:test_class) do
      Class.new do
        extend Smolagents::Builders::Support::SetterFactory

        def initialize
          @config = {}
        end

        attr_reader :config

        define_setters({
                         name: { key: :name },
                         count: { key: :item_count },
                         items: { key: :items, transform: :flatten },
                         label: { key: :label, transform: :to_sym }
                       })
      end
    end

    let(:builder) { test_class.new }

    it "generates simple setter methods" do
      result = builder.name("test")

      expect(result).to eq(builder) # Returns self
      expect(builder.config[:name]).to eq("test")
    end

    it "uses custom config key" do
      builder.count(5)

      expect(builder.config[:item_count]).to eq(5)
    end

    it "applies flatten transform" do
      builder.items([:a, %i[b c]])

      expect(builder.config[:items]).to eq(%i[a b c])
    end

    it "applies to_sym transform" do
      builder.label("foo")

      expect(builder.config[:label]).to eq(:foo)
    end

    it "supports method chaining" do
      result = builder.name("test").count(5).items([:a])

      expect(result).to eq(builder)
      expect(builder.config).to eq({ name: "test", item_count: 5, items: [:a] })
    end
  end

  describe ".define_setters (immutable)" do
    let(:test_class) do
      Class.new do
        extend Smolagents::Builders::Support::SetterFactory
        include Smolagents::Builders::Support::Configurable

        def self.create = new(configuration: {})

        attr_reader :configuration

        def initialize(configuration:)
          @configuration = configuration
        end

        define_setters({
                         name: { key: :name },
                         count: { key: :item_count }
                       }, immutable: true)
      end
    end

    let(:builder) { test_class.create }

    it "returns new instance" do
      new_builder = builder.name("test")

      expect(new_builder).not_to eq(builder)
      expect(new_builder.configuration[:name]).to eq("test")
      expect(builder.configuration[:name]).to be_nil
    end

    it "supports method chaining immutably" do
      final = builder.name("test").count(5)

      expect(builder.configuration).to eq({})
      expect(final.configuration).to eq({ name: "test", item_count: 5 })
    end
  end

  describe "varargs handling" do
    let(:test_class) do
      Class.new do
        extend Smolagents::Builders::Support::SetterFactory

        def initialize
          @config = {}
        end

        attr_reader :config

        define_setters({
                         items: { key: :items, transform: :flatten }
                       })
      end
    end

    let(:builder) { test_class.new }

    it "handles single array argument" do
      builder.items(%i[a b])

      expect(builder.config[:items]).to eq(%i[a b])
    end

    it "handles multiple arguments" do
      builder.items(:a, :b, :c)

      expect(builder.config[:items]).to eq(%i[a b c])
    end
  end
end
