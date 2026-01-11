module Smolagents
  module Agents
    class WebResearcher < ToolCalling
      def initialize(model:, **opts)
        tools = [
          Tools::DuckDuckGoSearchTool.new,
          Tools::VisitWebpageTool.new,
          Tools::FinalAnswerTool.new
        ]
        super(tools: tools, model: model, **opts)
      end
    end
  end
end
