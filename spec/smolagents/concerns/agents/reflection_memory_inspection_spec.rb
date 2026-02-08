RSpec.describe Smolagents::Concerns::ReflectionMemory, "#reflection_count and #reflections_summary" do
  let(:host) do
    Class.new do
      include Smolagents::Concerns::ReflectionMemory

      def initialize = initialize_reflection_memory
    end.new
  end

  describe "#reflection_count" do
    it "returns 0 for empty store" do
      expect(host.reflection_count).to eq(0)
    end
  end

  describe "#reflections_summary" do
    it "reports zero reflections" do
      expect(host.reflections_summary).to eq("0 reflections (0 failures, 0 successes)")
    end
  end
end
