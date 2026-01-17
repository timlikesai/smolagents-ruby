# Shared examples for builder fluent API patterns.
# These complement the builder_behavior.rb shared examples with higher-level patterns.

# Tests that a builder supports fluent method chaining with immutability.
# Required let variables:
#   - builder: the builder instance to test
#   - fluent_chain: array of [method, args] pairs to chain
RSpec.shared_examples_for "a fluent builder" do
  describe "fluent method chaining" do
    it "returns the same builder class for each chained method" do
      result = fluent_chain.reduce(builder) do |b, (method, args)|
        b.public_send(method, *args)
      end

      expect(result).to be_a(described_class)
    end

    it "preserves configuration through the chain" do
      final_builder = fluent_chain.reduce(builder) do |b, (method, args)|
        b.public_send(method, *args)
      end

      # Each config key from the chain should be set
      expect(final_builder.config).to be_a(Hash)
      expect(final_builder.config.keys.size).to be >= fluent_chain.size
    end

    it "returns a new instance for each method call (immutability)" do
      instances = [builder]
      fluent_chain.reduce(builder) do |b, (method, args)|
        new_b = b.public_send(method, *args)
        instances << new_b
        new_b
      end

      # All instances should be different objects
      expect(instances.uniq.size).to eq(instances.size)
    end

    it "does not mutate previous builder instances in the chain" do
      original_config = builder.config.dup

      fluent_chain.reduce(builder) do |b, (method, args)|
        b.public_send(method, *args)
      end

      expect(builder.config).to eq(original_config)
    end
  end
end

# Tests that a builder properly merges configuration across method calls.
# Required let variables:
#   - builder: the builder instance to test
#   - config_method: method name that sets config (symbol)
#   - config_key: the key in config hash that gets set (symbol)
#   - config_values: array of [input_value, expected_value] pairs to test
#   - accumulates: boolean - true if values accumulate (like tools), false if they replace
RSpec.shared_examples_for "a configurable builder" do
  describe "configuration merging" do
    it "sets config values correctly" do
      config_values.each do |input, expected|
        result = builder.public_send(config_method, *Array(input))
        expect(result.config[config_key]).to eq(expected)
      end
    end

    context "when called multiple times" do
      if defined?(accumulates) && accumulates
        it "accumulates values across calls" do
          first_input, first_expected = config_values.first
          second_input, second_expected = config_values.last

          result = builder
                   .public_send(config_method, *Array(first_input))
                   .public_send(config_method, *Array(second_input))

          # For accumulating configs, expect combined values
          actual = result.config[config_key]
          expect(actual).to include(*Array(first_expected))
          expect(actual).to include(*Array(second_expected))
        end
      else
        it "replaces values on subsequent calls" do
          first_input, = config_values.first
          second_input, second_expected = config_values.last

          result = builder
                   .public_send(config_method, *Array(first_input))
                   .public_send(config_method, *Array(second_input))

          expect(result.config[config_key]).to eq(second_expected)
        end
      end
    end

    it "preserves other config values when setting this one" do
      # Find an unrelated method to set up base config
      # Skip this test if config_method is :max_steps and only max_steps is available
      other_method = if config_method != :max_steps && builder.respond_to?(:max_steps)
                       :max_steps
                     elsif config_method != :coordinate && builder.respond_to?(:coordinate)
                       :coordinate
                     elsif config_method != :temperature && builder.respond_to?(:temperature)
                       :temperature
                     elsif config_method != :id && builder.respond_to?(:id)
                       :id
                     end

      skip "No unrelated config method available for cross-preservation test" unless other_method

      args_map = {
        max_steps: [10],
        coordinate: ["Test coordination"],
        temperature: [0.5],
        id: ["test-model"]
      }
      other_args = args_map[other_method]

      key_map = {
        max_steps: :max_steps,
        coordinate: :coordinator_instructions,
        temperature: :temperature,
        id: :model_id
      }
      other_key = key_map[other_method]

      base = builder.public_send(other_method, *other_args)
      input, expected = config_values.first
      result = base.public_send(config_method, *Array(input))

      expect(result.config[config_key]).to eq(expected)
      expect(result.config[other_key]).to eq(other_args.first)
    end
  end
end

# Combined example for typical builder behavior - fluent API + configuration.
# Required let variables:
#   - builder: the builder instance to test
#   - fluent_chain: array of [method, args] pairs to chain
#   - build_method: the method to call to build the final object (default: :build)
RSpec.shared_examples_for "a complete fluent builder" do
  it_behaves_like "a fluent builder"

  let(:build_method) { :build }

  describe "#inspect" do
    it "returns a string representation" do
      expect(builder.inspect).to be_a(String)
      expect(builder.inspect).to include(described_class.name.split("::").last)
    end
  end

  describe "#config" do
    it "returns a hash" do
      expect(builder.config).to be_a(Hash)
    end

    it "returns configuration hash alias" do
      expect(builder.configuration).to eq(builder.config) if builder.respond_to?(:configuration)
    end
  end
end
