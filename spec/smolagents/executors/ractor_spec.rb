RSpec.describe Smolagents::RactorExecutor do
  let(:executor) { described_class.new }

  it_behaves_like "a ruby executor"

  describe "Ractor-specific behavior" do
    it "provides true isolation by blocking global variable access" do
      # Ractors cannot access global variables - this is the isolation mechanism
      result = executor.execute("$global = 100", language: :ruby)

      # Global variable access should fail in Ractor
      expect(result.failure?).to be true
      expect(result.error).to match(/global variable|Ractor::IsolationError/i)
    end

    it "handles complex data structures" do
      result = executor.execute('{ a: [1, 2, 3], b: { nested: "value" } }', language: :ruby)
      expect(result.success?).to be true
      expect(result.output).to eq({ a: [1, 2, 3], b: { nested: "value" } })
    end

    it "preserves variable types across Ractor boundary" do
      executor.send_variables({ "arr" => [1, 2, 3], "hash" => { key: "value" } })
      result = executor.execute("[arr.class, hash.class]", language: :ruby)

      expect(result.success?).to be true
      expect(result.output).to eq([Array, Hash])
    end
  end
end
