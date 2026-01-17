require_relative "sandbox/ruby_safety"
require_relative "sandbox/sandbox_methods"

module Smolagents
  module Concerns
    # Unified sandbox concern for code validation and safe execution.
    #
    # Combines static code analysis (RubySafety) with runtime method
    # injection (SandboxMethods) for secure code execution contexts.
    #
    # @!group Concern Dependency Graph
    #
    # == Dependency Matrix
    #
    #   | Concern        | Depends On       | Depended By     | Auto-Includes |
    #   |----------------|------------------|-----------------|---------------|
    #   | RubySafety     | ripper (stdlib)  | Sandbox         | -             |
    #   | SandboxMethods | -                | LocalRubyExec   | -             |
    #   | Sandbox        | RubySafety       | -               | RubySafety    |
    #
    # == Sub-concern Methods
    #
    #   RubySafety
    #       +-- validate_ruby_code!(code) - Raise if unsafe patterns found
    #       +-- ruby_code_safe?(code) - Check safety without raising
    #       +-- unsafe_patterns - List of blocked patterns
    #       +-- extract_violations(code) - Get list of safety violations
    #
    #   SandboxMethods
    #       +-- define_sandbox_method(name, &block) - Add method to sandbox
    #       +-- sandbox_binding - Get binding with injected methods
    #       +-- sandbox_variables - Get hash of available variables
    #       +-- clear_sandbox - Reset sandbox state
    #
    # == Instance Variables Set
    #
    # *SandboxMethods*:
    # - @sandbox_methods [Hash] - Defined sandbox methods
    # - @sandbox_variables [Hash] - Injected variables
    # - @sandbox_binding [Binding] - Cached binding object
    #
    # == Security Patterns Blocked (RubySafety)
    #
    # - File system access (File, Dir, IO)
    # - Process control (system, exec, spawn, `)
    # - Metaprogramming (eval, define_method, const_set)
    # - Network access (Socket, Net::HTTP)
    # - Object space manipulation (ObjectSpace)
    #
    # @!endgroup
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
