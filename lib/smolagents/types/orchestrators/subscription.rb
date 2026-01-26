module Smolagents
  module Orchestrators
    class EventOrchestrator
      module Subscriptions
        # Internal subscription record.
        # @api private
        Subscription = Data.define(:id, :event_class, :handler)
      end
    end
  end
end
