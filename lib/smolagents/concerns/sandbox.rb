require_relative "sandbox/ruby_safety"
require_relative "sandbox/sandbox_methods"

module Smolagents
  module Concerns
    # Sandboxing concerns for safe code execution.
    #
    # Provides Ruby-specific safety checks and method restrictions
    # for executing untrusted code.
    #
    # == Sub-Modules
    #
    #   RubySafety
    #       Detect dangerous Ruby operations and patterns
    #
    #   SandboxMethods
    #       Methods for executing code in restricted environments
    #
    # @see RubySafety For dangerous operation detection
    # @see SandboxMethods For sandboxed execution helpers
    module Sandbox
    end
  end
end
