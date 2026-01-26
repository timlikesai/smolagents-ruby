RSpec.describe Smolagents::Types::TypeSupport::FactoryBuilder do
  # Test types for specs
  ResultType = Data.define(:status, :value, :error) do
    extend Smolagents::Types::TypeSupport::FactoryBuilder

    factory :success, status: :ok, error: nil
    factory :failure, status: :failed, value: nil
    factory :empty, status: :ok, value: nil, error: nil
  end

  TypeWithFactories = Data.define(:state, :count) do
    extend Smolagents::Types::TypeSupport::FactoryBuilder

    factories initial: { state: :initial, count: 0 },
              done: { state: :done, count: 100 }
  end

  describe ".factory" do
    it "creates a class method for the factory" do
      expect(ResultType).to respond_to(:success)
      expect(ResultType).to respond_to(:failure)
      expect(ResultType).to respond_to(:empty)
    end

    it "creates instance with default values" do
      result = ResultType.empty

      expect(result.status).to eq(:ok)
      expect(result.value).to be_nil
      expect(result.error).to be_nil
    end

    it "allows overriding defaults" do
      result = ResultType.success(value: "hello")

      expect(result.status).to eq(:ok)
      expect(result.value).to eq("hello")
      expect(result.error).to be_nil
    end

    it "allows overriding all values" do
      result = ResultType.success(value: "data", error: "warning", status: :partial)

      expect(result.status).to eq(:partial)
      expect(result.value).to eq("data")
      expect(result.error).to eq("warning")
    end

    it "requires non-defaulted parameters" do
      expect { ResultType.success }.to raise_error(ArgumentError)
    end
  end

  describe ".factories" do
    it "creates multiple factory methods at once" do
      expect(TypeWithFactories).to respond_to(:initial)
      expect(TypeWithFactories).to respond_to(:done)
    end

    it "creates instances with correct defaults" do
      initial = TypeWithFactories.initial
      done = TypeWithFactories.done

      expect(initial.state).to eq(:initial)
      expect(initial.count).to eq(0)
      expect(done.state).to eq(:done)
      expect(done.count).to eq(100)
    end

    it "allows overriding" do
      result = TypeWithFactories.initial(count: 5)

      expect(result.state).to eq(:initial)
      expect(result.count).to eq(5)
    end
  end

  describe "returned instances" do
    it "returns proper Data.define instances" do
      result = ResultType.success(value: "test")

      expect(result).to be_a(ResultType)
      expect(result).to be_frozen
    end

    it "supports pattern matching" do
      result = ResultType.success(value: "test")

      matched = case result
                in ResultType[status: :ok, value:]
                  value
                end

      expect(matched).to eq("test")
    end
  end
end
