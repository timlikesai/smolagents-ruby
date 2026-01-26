module Smolagents
  module Executors
    # What gets yielded when futures need resolution.
    BatchYield = Data.define(:futures) do
      def tool_names = futures.map(&:tool_name)
      def size = futures.size
      def to_s = "BatchYield[#{size} tools: #{tool_names.join(", ")}]"
    end
  end
end
