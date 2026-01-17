# Validation concerns for external feedback and oracle patterns.
#
# Small models cannot self-correct reasoning errors, but CAN correct
# based on external feedback. These concerns provide structured validation
# and feedback mechanisms.
#
# == Concerns
#
# - {ExecutionOracle} - Parses execution results into actionable feedback
#
# @example Using the execution oracle
#   include Concerns::ExecutionOracle
#
#   feedback = analyze_execution(result, code)
#   if feedback.actionable?
#     inject_feedback(feedback)
#   end
module Smolagents
  module Concerns
    module Validation
    end
  end
end

require_relative "validation/execution_oracle"
require_relative "validation/goal_drift"
