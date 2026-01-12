module Smolagents
  module Agents
    class Code < Agent
      include Concerns::CodeExecution

      def initialize(tools:, model:, executor: nil, authorized_imports: nil, **opts)
        setup_code_execution(executor: executor, authorized_imports: authorized_imports)
        super(tools: tools, model: model, **opts)
        finalize_code_execution
      end
    end
  end
end
