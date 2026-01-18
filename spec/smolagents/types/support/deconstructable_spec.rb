RSpec.describe Smolagents::Types::TypeSupport::Deconstructable do
  # Test type for specs
  TestPoint = Data.define(:x, :y) do
    include Smolagents::Types::TypeSupport::Deconstructable
  end

  let(:point) { TestPoint.new(x: 10, y: 20) }

  describe "#deconstruct_keys" do
    it "returns all members when keys is nil" do
      result = point.deconstruct_keys(nil)

      expect(result).to eq(x: 10, y: 20)
    end

    it "returns only requested keys" do
      result = point.deconstruct_keys([:x])

      expect(result).to eq(x: 10)
    end

    it "ignores non-existent keys" do
      result = point.deconstruct_keys(%i[x z])

      expect(result).to eq(x: 10)
    end

    it "returns empty hash when no keys match" do
      result = point.deconstruct_keys([:z])

      expect(result).to eq({})
    end
  end

  describe "pattern matching support" do
    it "works with case/in expressions" do
      result = case point
               in TestPoint[x:, y:]
                 x + y
               end

      expect(result).to eq(30)
    end

    it "works with partial matching" do
      result = case point
               in { x: 10 }
                 "matched"
               else
                 "no match"
               end

      expect(result).to eq("matched")
    end

    it "works with guard clauses" do
      result = case point
               in TestPoint[x:, y:] if x < y
                 "x less than y"
               else
                 "other"
               end

      expect(result).to eq("x less than y")
    end
  end
end
