# Engine-level agent concern registrations (Phase K).
module Smolagents
  module Concerns
    Registry.tap do |r|
      r.register :multi_turn,
                 Smolagents::Concerns::MultiTurn,
                 category: :agents,
                 dependencies: %i[react_loop],
                 provides: %i[continue reset_conversation! conversation_turns turn_number],
                 description: "Multi-turn conversation with memory accumulation"

      r.register :cancellation,
                 Smolagents::Concerns::Cancellation,
                 category: :agents,
                 dependencies: %i[react_loop],
                 provides: %i[cancel! cancelled? cancellation_token],
                 description: "Graceful agent cancellation via token"

      r.register :cost_accounting,
                 Smolagents::Concerns::CostAccounting,
                 category: :agents,
                 provides: %i[token_budget tokens_consumed remaining_token_budget check_token_budget!],
                 description: "Token budget tracking and enforcement"
    end
  end
end
