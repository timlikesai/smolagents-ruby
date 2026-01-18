RSpec.describe Smolagents::Builders::Support::Validators do
  describe "POSITIVE_INTEGER" do
    subject(:validator) { described_class::POSITIVE_INTEGER }

    it { expect(validator.call(1)).to be true }
    it { expect(validator.call(100)).to be true }
    it { expect(validator.call(0)).to be false }
    it { expect(validator.call(-1)).to be false }
    it { expect(validator.call(1.5)).to be false }
    it { expect(validator.call("1")).to be false }
  end

  describe "NON_NEGATIVE_INTEGER" do
    subject(:validator) { described_class::NON_NEGATIVE_INTEGER }

    it { expect(validator.call(0)).to be true }
    it { expect(validator.call(1)).to be true }
    it { expect(validator.call(-1)).to be false }
  end

  describe "NON_EMPTY_STRING" do
    subject(:validator) { described_class::NON_EMPTY_STRING }

    it { expect(validator.call("hello")).to be true }
    it { expect(validator.call("")).to be false }
    it { expect(validator.call(nil)).to be false }
    it { expect(validator.call(123)).to be false }
  end

  describe "BOOLEAN" do
    subject(:validator) { described_class::BOOLEAN }

    it { expect(validator.call(true)).to be true }
    it { expect(validator.call(false)).to be true }
    it { expect(validator.call(nil)).to be false }
    it { expect(validator.call(1)).to be false }
    it { expect(validator.call("true")).to be false }
  end

  describe "SYMBOL" do
    subject(:validator) { described_class::SYMBOL }

    it { expect(validator.call(:foo)).to be true }
    it { expect(validator.call("foo")).to be false }
  end

  describe "ARRAY" do
    subject(:validator) { described_class::ARRAY }

    it { expect(validator.call([])).to be true }
    it { expect(validator.call([1, 2])).to be true }
    it { expect(validator.call(nil)).to be false }
  end

  describe "CALLABLE" do
    subject(:validator) { described_class::CALLABLE }

    it { expect(validator.call(-> {})).to be true }
    it { expect(validator.call(proc {})).to be true }
    it { expect(validator.call("string")).to be false }
  end

  describe ".numeric_range" do
    subject(:validator) { described_class.numeric_range(0.0, 2.0) }

    it { expect(validator.call(0.0)).to be true }
    it { expect(validator.call(1.0)).to be true }
    it { expect(validator.call(2.0)).to be true }
    it { expect(validator.call(-0.1)).to be false }
    it { expect(validator.call(2.1)).to be false }
    it { expect(validator.call("1.0")).to be false }
  end

  describe ".integer_range" do
    subject(:validator) { described_class.integer_range(1, 100) }

    it { expect(validator.call(1)).to be true }
    it { expect(validator.call(50)).to be true }
    it { expect(validator.call(100)).to be true }
    it { expect(validator.call(0)).to be false }
    it { expect(validator.call(101)).to be false }
    it { expect(validator.call(50.5)).to be false }
  end

  describe ".one_of" do
    subject(:validator) { described_class.one_of(:a, :b, :c) }

    it { expect(validator.call(:a)).to be true }
    it { expect(validator.call(:b)).to be true }
    it { expect(validator.call(:d)).to be false }
  end

  describe ".array_of" do
    subject(:validator) { described_class.array_of(:a, :b, :c) }

    it { expect(validator.call(%i[a b])).to be true }
    it { expect(validator.call([])).to be true }
    it { expect(validator.call(%i[a d])).to be false }
    it { expect(validator.call(:a)).to be false }
  end

  describe ".array_where" do
    subject(:validator) { described_class.array_where(described_class::POSITIVE_INTEGER) }

    it { expect(validator.call([1, 2, 3])).to be true }
    it { expect(validator.call([])).to be true }
    it { expect(validator.call([1, 0, 3])).to be false }
  end

  describe ".all_of" do
    subject(:validator) do
      described_class.all_of(
        described_class::NUMERIC,
        described_class.numeric_range(0, 100)
      )
    end

    it { expect(validator.call(50)).to be true }
    it { expect(validator.call(150)).to be false }
    it { expect(validator.call("50")).to be false }
  end

  describe ".any_of" do
    subject(:validator) do
      described_class.any_of(
        described_class::SYMBOL,
        described_class::NON_EMPTY_STRING
      )
    end

    it { expect(validator.call(:foo)).to be true }
    it { expect(validator.call("foo")).to be true }
    it { expect(validator.call(123)).to be false }
  end
end
