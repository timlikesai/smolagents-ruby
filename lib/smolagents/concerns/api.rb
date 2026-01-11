module Smolagents
  module Concerns
    module Api
      class ApiError < StandardError; end

      def require_success!(response, message: nil)
        return if response.success?

        raise ApiError, message || "API returned status #{response.status}"
      end
    end
  end
end
