require_relative "support/request_building"
require_relative "support/response_parsing"
require_relative "support/generate_template"

module Smolagents
  module Models
    # Shared support modules for model implementations.
    #
    # These modules extract common patterns from OpenAIModel and AnthropicModel
    # to reduce duplication while keeping provider-specific logic separate.
    #
    # @example Including all support modules
    #   class MyModel < Model
    #     include ModelSupport::RequestBuilding
    #     include ModelSupport::ResponseParsing
    #     include ModelSupport::GenerateTemplate
    #   end
    module ModelSupport
    end
  end
end
