RSpec.describe Smolagents::Builders::Support::Configurable do
  let(:test_class) do
    Class.new do
      include Smolagents::Builders::Support::Configurable

      attr_reader :configuration

      def initialize(configuration:)
        @configuration = configuration
      end
    end
  end

  describe "#with_config" do
    it "returns new instance with merged configuration" do
      original = test_class.new(configuration: { a: 1, b: 2 })

      result = original.send(:with_config, b: 3, c: 4)

      expect(result).to be_a(test_class)
      expect(result).not_to eq(original)
      expect(result.configuration).to eq({ a: 1, b: 3, c: 4 })
    end

    it "does not modify original instance" do
      original = test_class.new(configuration: { a: 1 })

      original.send(:with_config, b: 2)

      expect(original.configuration).to eq({ a: 1 })
    end

    it "works with empty initial configuration" do
      original = test_class.new(configuration: {})

      result = original.send(:with_config, key: "value")

      expect(result.configuration).to eq({ key: "value" })
    end

    it "overwrites existing keys" do
      original = test_class.new(configuration: { name: "old" })

      result = original.send(:with_config, name: "new")

      expect(result.configuration[:name]).to eq("new")
    end
  end

  context "with Data.define pattern" do
    let(:data_class) do
      Class.new(Data.define(:configuration)) do
        include Smolagents::Builders::Support::Configurable

        def max_steps(count) = with_config(max_steps: count)
      end
    end

    it "works with Data.define classes" do
      builder = data_class.new(configuration: {})

      result = builder.max_steps(10)

      expect(result.configuration[:max_steps]).to eq(10)
      expect(builder.configuration).to eq({})
    end

    it "enables fluent chaining" do
      builder = data_class.new(configuration: {})

      result = builder
               .max_steps(10)
               .max_steps(20)

      expect(result.configuration[:max_steps]).to eq(20)
    end
  end
end
