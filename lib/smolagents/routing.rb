# frozen_string_literal: true

module Smolagents
  # Tool routing and model orchestration.
  #
  # This module provides infrastructure for using small, fast models
  # as tool routers with fallback to larger primary models.
  module Routing
  end
end

require_relative "routing/model_profiles"
require_relative "routing/tool_router"
require_relative "routing/model_evaluator"
