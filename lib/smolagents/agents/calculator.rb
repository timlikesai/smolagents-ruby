module Smolagents
  module Agents
    class Calculator < Code
      def initialize(model:, **opts)
        tools = [
          Tools::RubyInterpreterTool.new,
          Tools::FinalAnswerTool.new
        ]
        super(tools: tools, model: model, **opts)
      end
    end
  end
end
