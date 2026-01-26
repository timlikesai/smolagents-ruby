require_relative "retry_policy/config"
require_relative "retry_policy/classification"

module Smolagents
  module Concerns
    # Alias for brevity within concerns.
    # The actual type is in Smolagents::Types::RetryPolicy.
    # @see Smolagents::Types::RetryPolicy
    RetryPolicy = Smolagents::Types::RetryPolicy
  end
end
