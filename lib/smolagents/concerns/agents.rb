# Agent behavior concerns for building intelligent agents.
#
# Each concern can be included independently or composed together.
# See {Registry} for concern metadata and {Compositions} for common patterns.
#
# @example Minimal code agent
#   class MyAgent
#     include Concerns::ReActLoop
#     include Concerns::CodeExecution
#   end
#
# @example Full-featured agent with composition
#   class MyAgent
#     include Concerns::Compositions::FullFeatured
#   end
#
# @see Registry For concern metadata and dependencies
# @see Compositions For predefined concern combinations

require_relative "agents/registry"
require_relative "agents/compositions"

# Load all agent concerns
%w[
  evaluation
  react_loop
  planning
  managed
  async
  early_yield
  specialized
  self_refine
  reflection_memory
  mixed_refinement
].each { |concern| require_relative "agents/#{concern}" }

module Smolagents
  module Concerns
    # Agent behavior concerns namespace.
    # @see Registry For concern metadata
    # @see Compositions For common patterns
    module Agents
    end
  end
end
