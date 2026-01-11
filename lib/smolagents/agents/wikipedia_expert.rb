module Smolagents
  module Agents
    class WikipediaExpert < ToolCalling
      def initialize(model:, **opts)
        tools = [
          Tools::WikipediaSearchTool.new,
          Tools::FinalAnswerTool.new
        ]
        super(tools: tools, model: model, **opts)
      end
    end
  end
end
