module Smolagents
  module Orchestrators
    class AgentPool
      # Task data for agent pool execution.
      TaskData = Data.define(:agent_name, :prompt, :config, :timeout)
    end
  end
end
