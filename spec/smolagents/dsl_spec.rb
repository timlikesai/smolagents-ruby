RSpec.describe Smolagents::DSL do
  # Define TestBuilder as a constant for pattern matching
  TestBuilder = Smolagents::DSL.Builder(:target, :configuration) do
    # Register methods with validation
    builder_method :max_retries,
                   description: "Set maximum retry attempts (1-10)",
                   validates: ->(v) { v.is_a?(Integer) && (1..10).cover?(v) },
                   aliases: [:retries]

    builder_method :timeout,
                   description: "Set timeout in seconds (1-300)",
                   validates: ->(v) { v.is_a?(Integer) && v.positive? && v <= 300 }

    # Default configuration
    def self.default_configuration
      { max_retries: 3, timeout: 30, enabled: true }
    end

    # Factory method
    def self.create(target)
      new(target: target, configuration: default_configuration)
    end

    # Builder methods
    def max_retries(n)
      check_frozen!
      validate!(:max_retries, n)
      with_config(max_retries: n)
    end
    alias_method :retries, :max_retries

    def timeout(seconds)
      check_frozen!
      validate!(:timeout, seconds)
      with_config(timeout: seconds)
    end

    def enabled(value)
      check_frozen!
      with_config(enabled: value)
    end

    # Build method
    def build
      { target: target, **configuration.except(:__frozen__) }
    end

    # Inspect for debugging
    def inspect
      "#<TestBuilder target=#{target} retries=#{configuration[:max_retries]}>"
    end

    private

    def with_config(**kwargs)
      self.class.new(target: target, configuration: configuration.merge(kwargs))
    end
  end

  describe ".Builder" do
    let(:builder) { TestBuilder.create(:test_target) }

    describe "automatic Base inclusion" do
      it "includes Base module" do
        expect(TestBuilder.ancestors).to include(Smolagents::Builders::Base)
      end

      it "has builder_method class method" do
        expect(TestBuilder).to respond_to(:builder_method)
      end

      it "has help instance method" do
        expect(builder).to respond_to(:help)
      end

      it "has freeze! instance method" do
        expect(builder).to respond_to(:freeze!)
      end

      it "has validate! instance method" do
        expect(builder).to respond_to(:validate!)
      end

      it "has check_frozen! instance method" do
        expect(builder).to respond_to(:check_frozen!)
      end
    end

    describe ".help" do
      it "shows available methods" do
        help_text = builder.help

        expect(help_text).to include("TestBuilder - Available Methods")
        expect(help_text).to include(".max_retries")
        expect(help_text).to include(".timeout")
        expect(help_text).to include("aliases: retries")
      end

      it "shows method descriptions" do
        help_text = builder.help

        expect(help_text).to include("Set maximum retry attempts (1-10)")
        expect(help_text).to include("Set timeout in seconds (1-300)")
      end

      it "shows current configuration" do
        help_text = builder.help

        expect(help_text).to include("Current Configuration:")
        expect(help_text).to include("target=test_target")
      end

      it "shows pattern matching syntax" do
        help_text = builder.help

        expect(help_text).to include("Pattern Matching:")
        expect(help_text).to include("case builder")
      end
    end

    describe "validation" do
      it "validates max_retries range" do
        expect { builder.max_retries(0) }.to raise_error(ArgumentError, /Invalid value for max_retries/)
        expect { builder.max_retries(11) }.to raise_error(ArgumentError, /Invalid value for max_retries/)

        expect { builder.max_retries(1) }.not_to raise_error
        expect { builder.max_retries(5) }.not_to raise_error
        expect { builder.max_retries(10) }.not_to raise_error
      end

      it "validates timeout range" do
        expect { builder.timeout(0) }.to raise_error(ArgumentError, /Invalid value for timeout/)
        expect { builder.timeout(-5) }.to raise_error(ArgumentError, /Invalid value for timeout/)
        expect { builder.timeout(301) }.to raise_error(ArgumentError, /Invalid value for timeout/)

        expect { builder.timeout(1) }.not_to raise_error
        expect { builder.timeout(30) }.not_to raise_error
        expect { builder.timeout(300) }.not_to raise_error
      end

      it "includes helpful error messages" do
        expect { builder.max_retries(15) }.to raise_error(ArgumentError) do |error|
          expect(error.message).to include("Set maximum retry attempts (1-10)")
        end
      end
    end

    describe ".freeze!" do
      it "returns a frozen builder" do
        frozen = builder.max_retries(5).freeze!

        expect(frozen.frozen_config?).to be true
      end

      it "prevents further modifications" do
        frozen = builder.max_retries(5).timeout(60).freeze!

        expect { frozen.max_retries(3) }.to raise_error(FrozenError, /Cannot modify frozen/)
        expect { frozen.timeout(30) }.to raise_error(FrozenError, /Cannot modify frozen/)
      end

      it "preserves configuration before freezing" do
        frozen = builder.max_retries(7).timeout(90).enabled(false).freeze!

        expect(frozen.configuration[:max_retries]).to eq(7)
        expect(frozen.configuration[:timeout]).to eq(90)
        expect(frozen.configuration[:enabled]).to be false
      end

      it "can still build frozen configuration" do
        frozen = builder.max_retries(5).freeze!

        result = frozen.build

        expect(result).to eq(target: :test_target, max_retries: 5, timeout: 30, enabled: true)
      end

      it "does not affect unfrozen builders" do
        unfrozen = builder.max_retries(5)
        unfrozen.freeze!

        expect(unfrozen.frozen_config?).to be false
        expect { unfrozen.timeout(60) }.not_to raise_error
      end
    end

    describe "convenience aliases" do
      it "supports .retries for .max_retries" do
        builder_with_retries = builder.retries(7)

        expect(builder_with_retries.configuration[:max_retries]).to eq(7)
      end

      it "validates through aliases" do
        expect { builder.retries(15) }.to raise_error(ArgumentError, /Invalid value for max_retries/)
      end
    end

    describe "immutability and chaining" do
      it "returns new builder instances" do
        builder1 = TestBuilder.create(:test)
        builder2 = builder1.max_retries(5)
        builder3 = builder2.timeout(60)

        expect(builder1.configuration[:max_retries]).to eq(3)  # Default
        expect(builder2.configuration[:max_retries]).to eq(5)
        expect(builder2.configuration[:timeout]).to eq(30)     # Default
        expect(builder3.configuration[:timeout]).to eq(60)
      end

      it "supports method chaining" do
        final_builder = TestBuilder.create(:my_target)
                                   .max_retries(8)
                                   .timeout(120)
                                   .enabled(false)

        expect(final_builder.configuration[:max_retries]).to eq(8)
        expect(final_builder.configuration[:timeout]).to eq(120)
        expect(final_builder.configuration[:enabled]).to be false
      end
    end

    describe "pattern matching" do
      it "supports pattern matching on builder" do
        configured = builder.max_retries(5).timeout(90)

        result = case configured
                 in TestBuilder[target: :test_target, configuration: { max_retries:, timeout: }]
                   "Retries: #{max_retries}, Timeout: #{timeout}"
                 else
                   "no match"
                 end

        expect(result).to eq("Retries: 5, Timeout: 90")
      end

      it "supports destructuring configuration" do
        configured = builder
                     .max_retries(9)
                     .timeout(150)
                     .enabled(false)

        case configured
        in TestBuilder[configuration: { max_retries:, timeout:, enabled: }]
          expect(max_retries).to eq(9)
          expect(timeout).to eq(150)
          expect(enabled).to be false
        end
      end
    end

    describe ".build" do
      it "builds the configured object" do
        configured = builder.max_retries(6).timeout(100).enabled(true)

        result = configured.build

        expect(result).to eq(
          target: :test_target,
          max_retries: 6,
          timeout: 100,
          enabled: true
        )
      end
    end

    describe "integration with Data.define" do
      it "creates a Data.define instance" do
        expect(TestBuilder.ancestors).to include(Data)
      end

      it "has Data.define attributes" do
        expect(TestBuilder.members).to eq(%i[target configuration])
      end

      it "instances are frozen by Ruby" do
        expect(builder.frozen?).to be true
      end

      it "uses configuration marker for freeze! logic" do
        frozen = builder.freeze!
        expect(frozen.configuration[:__frozen__]).to be true
      end
    end
  end
end
