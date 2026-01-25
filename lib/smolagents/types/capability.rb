module Smolagents
  module Types
    # Declaration of a capability an agent possesses.
    #
    # Used in agent specifications to declare what tools an agent can use.
    #
    # @!attribute [r] tool
    #   @return [Symbol] The tool name
    # @!attribute [r] description
    #   @return [String, nil] Optional description of the capability
    #
    # @example Declaring a capability
    #   cap = Capability.new(tool: :search_web, description: "find information online")
    #
    # @see Testing::AgentSpec For usage in agent specifications
    Capability = Data.define(:tool, :description) do
      include TypeSupport::Deconstructable
      include TypeSupport::Serializable
    end
  end
end
