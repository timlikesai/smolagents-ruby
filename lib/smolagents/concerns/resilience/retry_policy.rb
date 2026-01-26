require_relative "retry_policy/config"
require_relative "retry_policy/classification"

module Smolagents
  module Concerns
    # Retry policy configuration and error classification.
    #
    # The actual RetryPolicy type is in Types::RetryPolicy.
    # This module provides configuration constants and classification helpers.
    #
    # @see Types::RetryPolicy The retry policy value type
    # @see RetryPolicyConfig For configuration constants
    # @see RetryPolicyClassification For error classification
    module RetryPolicy
      include RetryPolicyConfig
      include RetryPolicyClassification
    end
  end
end
