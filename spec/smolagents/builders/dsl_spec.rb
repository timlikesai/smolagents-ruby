require "spec_helper"

RSpec.describe Smolagents::DSL do
  describe ".Builder" do
    it "creates a Data.define class with Base included" do
      klass = described_class.Builder(:value) do
        def self.create(value)
          new(value:)
        end

        def current_value = value
      end

      builder = klass.create(42)
      expect(builder).to be_a(klass)
      expect(builder.value).to eq(42)
      expect(builder.current_value).to eq(42)
    end

    it "includes Base module automatically" do
      klass = described_class.Builder(:config) do
        def self.create
          new(config: {})
        end
      end

      builder = klass.create
      expect(builder).to respond_to(:help)
      expect(builder).to respond_to(:freeze!)
      expect(builder).to respond_to(:validate!)
    end

    it "supports multiple attributes" do
      klass = described_class.Builder(:name, :value, :enabled) do
        def self.create(name, value, enabled: true)
          new(name:, value:, enabled:)
        end
      end

      builder = klass.create("test", 100, enabled: false)
      expect(builder.name).to eq("test")
      expect(builder.value).to eq(100)
      expect(builder.enabled).to be(false)
    end

    it "supports immutable builder pattern" do
      klass = described_class.Builder(:configuration) do
        def self.create
          new(configuration: {})
        end

        def set_value(key, value)
          self.class.new(configuration: configuration.merge(key => value))
        end
      end

      builder1 = klass.create
      builder2 = builder1.set_value(:foo, "bar")

      expect(builder1).not_to equal(builder2)
      expect(builder1.configuration).to eq({})
      expect(builder2.configuration).to eq(foo: "bar")
    end

    it "works with Data.define pattern matching" do
      klass = described_class.Builder(:x, :y) do
        def self.create(coord_x, coord_y)
          new(x: coord_x, y: coord_y)
        end
      end

      builder = klass.create(10, 20)
      result = case builder
               in [x, y]
                 [x, y]
               end

      expect(result).to eq([10, 20])
    end

    it "evaluates block in class context" do
      klass = described_class.Builder(:value) do
        define_method(:double) { value * 2 }

        def self.test_class_method
          "class_method"
        end
      end

      builder = klass.new(value: 5)
      expect(builder.double).to eq(10)
      expect(klass.test_class_method).to eq("class_method")
    end

    it "handles empty block" do
      klass = described_class.Builder(:data)
      builder = klass.new(data: "test")

      expect(builder.data).to eq("test")
    end

    it "supports validation through register_method" do
      klass = described_class.Builder(:value) do
        register_method(:assign_value, description: "Set value", validates: ->(val) { val.is_a?(Integer) && val > 0 })

        def assign_value(val)
          validate!(:assign_value, val)
          self.class.new(value: val)
        end
      end

      builder = klass.new(value: 0)
      expect { builder.assign_value(-5) }.to raise_error(ArgumentError, /Invalid value/)
    end

    it "supports freeze capability" do
      klass = described_class.Builder(:configuration) do
        def with_config(new_config)
          check_frozen!
          self.class.new(configuration: new_config)
        end
      end

      builder = klass.new(configuration: {})
      frozen = builder.freeze!

      expect(frozen).to be_frozen
      expect { frozen.with_config({}) }.to raise_error(FrozenError)
    end
  end
end
