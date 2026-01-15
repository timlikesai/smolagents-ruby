require_relative "sandbox/ruby_safety"
require_relative "sandbox/sandbox_methods"

module Smolagents
  module Concerns
    # Unified sandbox concern for code validation and safe execution.
    #
    # Combines static code analysis (RubySafety) with runtime method
    # injection (SandboxMethods) for secure code execution contexts.
    #
    # @example Executor with full sandbox support
    #   class MyExecutor
    #     include Concerns::Sandbox
    #
    #     def execute(code)
    #       validate_ruby_code!(code)
    #       sandbox = SandboxContext.new
    #       sandbox.instance_eval(code)
    #     end
    #   end
    #
    # @see RubySafety For AST-based code validation
    # @see SandboxMethods For runtime method injection
    module Sandbox
      include RubySafety
    end
  end
end
