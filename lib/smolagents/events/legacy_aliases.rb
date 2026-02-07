# Convenience aliases for common event names.
#
# Maps shorter names to convention-derived canonical names so users can
# write `.on(:error)` instead of `.on(:error_occurred)`.

module Smolagents
  module Events
    Mappings.register_alias(:tool_call, :tool_call_requested)
    Mappings.register_alias(:tool_complete, :tool_call_completed)
    Mappings.register_alias(:step_complete, :step_completed)
    Mappings.register_alias(:agent_launch, :sub_agent_launched)
    Mappings.register_alias(:agent_progress, :sub_agent_progress)
    Mappings.register_alias(:agent_complete, :sub_agent_completed)
    Mappings.register_alias(:error, :error_occurred)
    Mappings.register_alias(:rate_limit, :rate_limit_violated)
    Mappings.register_alias(:retry, :retry_requested)
    Mappings.register_alias(:failover, :failover_occurred)
    Mappings.register_alias(:recovery, :recovery_completed)
  end
end
