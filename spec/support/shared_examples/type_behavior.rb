# Shared examples for Data.define type specs.
# Types are immutable value objects with common patterns.

RSpec.shared_examples "a frozen type" do
  it "is frozen on creation" do
    expect(instance).to be_frozen
  end
end

RSpec.shared_examples "a type with to_h" do |expected_keys:|
  describe "#to_h" do
    it "returns a hash" do
      expect(instance.to_h).to be_a(Hash)
    end

    it "has expected keys" do
      expect(instance.to_h.keys).to match_array(expected_keys)
    end
  end
end

RSpec.shared_examples "a type with predicates" do |predicates:|
  predicates.each do |predicate, conditions|
    describe "##{predicate}?" do
      conditions.each do |state, expected|
        it "returns #{expected} for #{state}" do
          obj = build_for_state(state)
          expect(obj.public_send(:"#{predicate}?")).to eq(expected)
        end
      end
    end
  end
end

RSpec.shared_examples "an immutable type" do
  it "is frozen" do
    expect(instance).to be_frozen
  end

  it "operations return new instances" do
    return skip("no operations defined") unless defined?(operation_name)

    result = instance.public_send(operation_name, *operation_args)
    expect(result).not_to equal(instance)
  end
end

RSpec.shared_examples "a type with zero factory" do
  describe ".zero" do
    it "returns a valid instance" do
      expect(described_class.zero).to be_a(described_class)
    end

    it "is frozen" do
      expect(described_class.zero).to be_frozen
    end
  end
end

RSpec.shared_examples "a combinable type" do
  describe "#+" do
    it "combines two instances" do
      result = instance_a + instance_b
      expect(result).to be_a(described_class)
    end

    it "returns new instance" do
      result = instance_a + instance_b
      expect(result).not_to equal(instance_a)
      expect(result).not_to equal(instance_b)
    end

    it "does not mutate operands" do
      original_a = instance_a.to_h.dup
      original_b = instance_b.to_h.dup
      _ = instance_a + instance_b # Perform operation but ignore result
      expect(instance_a.to_h).to eq(original_a)
      expect(instance_b.to_h).to eq(original_b)
    end
  end
end

RSpec.shared_examples "a pattern matchable type" do
  it "supports pattern matching with hash pattern" do
    matched = case instance
              in { **attrs }
                attrs
              end
    expect(matched).to be_a(Hash)
  end

  it "supports deconstruct_keys" do
    expect(instance).to respond_to(:deconstruct_keys)
    expect(instance.deconstruct_keys(nil)).to be_a(Hash)
  end
end

# For step types that have timing
RSpec.shared_examples "a timed step" do
  it "has timing information" do
    expect(step.timing).to respond_to(:start_time)
    expect(step.timing).to respond_to(:end_time)
  end

  it "can calculate duration" do
    expect(step.timing).to respond_to(:duration)
  end
end

# For types with DSL-generated predicates
RSpec.shared_examples "a DSL type with predicates" do |type_field:, types:|
  types.each do |type_name|
    describe "##{type_name}?" do
      it "returns true when #{type_field} is :#{type_name}" do
        obj = described_class.new(**{ type_field => type_name })
        expect(obj.public_send(:"#{type_name}?")).to be true
      end

      it "returns false for other types" do
        other_type = (types - [type_name]).first
        obj = described_class.new(**{ type_field => other_type })
        expect(obj.public_send(:"#{type_name}?")).to be false
      end
    end
  end
end
