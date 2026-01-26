RSpec.describe Smolagents::Types::TypeSupport::Serializable do
  # Test types for specs
  BasicType = Data.define(:a, :b) do
    include Smolagents::Types::TypeSupport::Serializable
  end

  TypeWithCalculated = Data.define(:amount, :quantity) do
    include Smolagents::Types::TypeSupport::Serializable

    calculated_field :total, -> { amount * quantity }
    calculated_field :formatted, -> { "$#{amount * quantity}" }
  end

  describe "#to_h" do
    context "with basic type (no calculated fields)" do
      let(:instance) { BasicType.new(a: 1, b: 2) }

      it "returns hash with all members" do
        expect(instance.to_h).to eq(a: 1, b: 2)
      end
    end

    context "with calculated fields" do
      let(:instance) { TypeWithCalculated.new(amount: 10, quantity: 3) }

      it "includes base members" do
        hash = instance.to_h

        expect(hash[:amount]).to eq(10)
        expect(hash[:quantity]).to eq(3)
      end

      it "includes calculated fields" do
        hash = instance.to_h

        expect(hash[:total]).to eq(30)
        expect(hash[:formatted]).to eq("$30")
      end

      it "returns all fields" do
        expect(instance.to_h).to eq(
          amount: 10,
          quantity: 3,
          total: 30,
          formatted: "$30"
        )
      end
    end
  end

  describe ".calculated_field" do
    it "stores the field name and proc" do
      fields = TypeWithCalculated.calculated_fields

      expect(fields).to include(:total)
      expect(fields).to include(:formatted)
    end

    it "evaluates proc in instance context" do
      instance = TypeWithCalculated.new(amount: 5, quantity: 2)

      expect(instance.to_h[:total]).to eq(10)
    end
  end

  describe "inheritance" do
    # Each type gets its own calculated_fields
    AnotherType = Data.define(:value) do
      include Smolagents::Types::TypeSupport::Serializable

      calculated_field :doubled, -> { value * 2 }
    end

    it "does not share calculated fields between types" do
      expect(TypeWithCalculated.calculated_fields.keys).to contain_exactly(:total, :formatted)
      expect(AnotherType.calculated_fields.keys).to contain_exactly(:doubled)
    end
  end
end
