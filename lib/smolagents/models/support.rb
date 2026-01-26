require_relative "support/request_building"
require_relative "support/response_parsing"
require_relative "support/generate_template"
require_relative "support/image_content"
require_relative "support/tool_schema"

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
