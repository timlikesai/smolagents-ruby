RSpec.describe Smolagents::Builders::Support::ValidatedSetter do
  let(:validators) { Smolagents::Builders::Support::Validators }

  let(:test_class) do
    Class.new(Data.define(:configuration)) do
      include Smolagents::Builders::Base
      extend Smolagents::Builders::Support::ValidatedSetter

      def self.create = new(configuration: {})

      register_method :max_steps, description: "Max steps",
                                  validates: ->(v) { v.is_a?(Integer) && v.positive? }
      register_method :temperature, description: "Temperature (0-2)",
                                    validates: ->(v) { v.is_a?(Numeric) && v.between?(0, 2) }
      register_method :name, description: "Name string",
                             validates: ->(v) { v.is_a?(String) && !v.empty? }

      validated_setter :max_steps, validate: :positive_integer
      validated_setter :temperature, validate: ->(v) { v.is_a?(Numeric) && v.between?(0, 2) }
      validated_setter :name, validate: :non_empty_string
      validated_setter :api_key, key: :api_key_value, validate: :non_empty_string
      validated_setter :imports, transform: :flatten

      private

      def with_config(**kwargs) = self.class.new(configuration: configuration.merge(kwargs))
    end
  end

  let(:builder) { test_class.create }

  describe ".validated_setter" do
    it "generates setter that returns new instance" do
      result = builder.max_steps(10)

      expect(result).not_to eq(builder)
      expect(result.configuration[:max_steps]).to eq(10)
      expect(builder.configuration[:max_steps]).to be_nil
    end

    it "validates with symbol validator reference" do
      expect { builder.max_steps(0) }.to raise_error(ArgumentError, /Invalid value/)
      expect { builder.max_steps(-1) }.to raise_error(ArgumentError, /Invalid value/)
    end

    it "validates with lambda validator" do
      expect { builder.temperature(3.0) }.to raise_error(ArgumentError, /Invalid value/)
      expect(builder.temperature(1.5).configuration[:temperature]).to eq(1.5)
    end

    it "uses custom config key" do
      result = builder.api_key("secret-key")

      expect(result.configuration[:api_key_value]).to eq("secret-key")
    end

    it "applies transform before storing" do
      result = builder.imports([:a, %i[b c]])

      expect(result.configuration[:imports]).to eq(%i[a b c])
    end

    it "checks frozen state" do
      frozen = builder.freeze!

      expect { frozen.max_steps(10) }.to raise_error(FrozenError)
    end

    it "enables fluent chaining" do
      result = builder
               .max_steps(10)
               .temperature(0.7)
               .name("test")

      expect(result.configuration).to include(
        max_steps: 10,
        temperature: 0.7,
        name: "test"
      )
    end
  end

  describe ".validated_setters" do
    let(:batch_class) do
      Class.new(Data.define(:configuration)) do
        include Smolagents::Builders::Base
        extend Smolagents::Builders::Support::ValidatedSetter

        def self.create = new(configuration: {})

        register_method :count, description: "Count", validates: ->(v) { v.is_a?(Integer) }
        register_method :enabled, description: "Enabled", validates: ->(v) { [true, false].include?(v) }

        validated_setters(
          count: { validate: :positive_integer },
          enabled: { validate: :boolean },
          items: { transform: :flatten }
        )

        private

        def with_config(**kwargs) = self.class.new(configuration: configuration.merge(kwargs))
      end
    end

    it "generates multiple setters" do
      builder = batch_class.create

      result = builder.count(5).enabled(true).items([:a, [:b]])

      expect(result.configuration).to eq({
                                           count: 5,
                                           enabled: true,
                                           items: %i[a b]
                                         })
    end
  end

  describe "varargs handling" do
    it "treats single arg as value" do
      result = builder.max_steps(10)

      expect(result.configuration[:max_steps]).to eq(10)
    end

    it "treats multiple args as array (for array setters)" do
      result = builder.imports(:a, :b, :c)

      expect(result.configuration[:imports]).to eq(%i[a b c])
    end
  end
end
