require_relative "executors/executor"
require_relative "executors/ruby"
require_relative "executors/docker"
require_relative "executors/ractor"

module Smolagents
  # Code execution environments for running agent-generated code.
  #
  # The Executors module contains all executor implementations that provide
  # sandboxed code execution for agents. Each executor handles a specific
  # execution context with appropriate security measures.
  #
  # Available executors:
  # - {LocalRuby} - Local Ruby execution with BasicObject sandbox
  # - {Docker} - Multi-language execution in Docker containers
  # - {Ractor} - Ruby 3.0+ Ractor-based parallel execution
  #
  # All executors share a common interface defined by {Executor} base class:
  # - `execute(code, language:, timeout:)` - Run code and return {Executor::ExecutionResult}
  # - `supports?(language)` - Check if language is supported
  # - `send_tools(tools)` - Register callable tools
  # - `send_variables(variables)` - Register accessible variables
  #
  # @example Using LocalRuby executor
  #   executor = Smolagents::Executors::LocalRuby.new(max_operations: 10_000)
  #   executor.send_tools("search" => search_tool)
  #   result = executor.execute("search(query: 'Ruby')", language: :ruby)
  #
  # @example Using backward-compatible aliases
  #   executor = Smolagents::LocalRubyExecutor.new
  #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
  #
  # @see Executor Base class defining the executor interface
  # @see LocalRuby Local Ruby execution with sandbox
  # @see Docker Multi-language Docker container execution
  # @see Ractor Ractor-based parallel execution
  module Executors
  end

  # Backward compatibility re-exports.
  # These allow existing code to use Smolagents::ClassName
  # instead of the full Smolagents::Executors::ClassName path.

  # @!parse
  #   # Abstract base class for code execution environments.
  #   #
  #   # Executor provides the interface for safely executing agent-generated code.
  #   # Concrete implementations handle specific languages and execution contexts
  #   # (local Ruby, Docker containers, Ractors, etc.).
  #   #
  #   # @example Using LocalRubyExecutor
  #   #   executor = Executor.new
  #   #   result = executor.execute("[1,2,3].sum", language: :ruby)
  #   #
  #   # @see Executors::Executor Base executor class
  #   Executor = Executors::Executor
  Executor = Executors::Executor

  # @!parse
  #   # Local Ruby code executor with sandbox isolation.
  #   #
  #   # LocalRuby runs agent-generated Ruby code in a restricted sandbox environment
  #   # with operation-based limits and comprehensive output capture.
  #   #
  #   # == Execution Model
  #   # Code runs in a Sandbox instance that extends BasicObject. Only explicitly
  #   # registered tools and variables are accessible.
  #   #
  #   # == Security Features
  #   # - BasicObject-based sandbox minimizes attack surface
  #   # - Operation counting prevents infinite loops
  #   # - Dangerous methods are blocked
  #   # - Output captured and truncated
  #   #
  #   # @example Basic execution
  #   #   executor = LocalRubyExecutor.new
  #   #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
  #   #   result.output  # => 6
  #   #
  #   # @see Executors::LocalRuby For full documentation
  #   LocalRubyExecutor = Executors::LocalRuby
  LocalRubyExecutor = Executors::LocalRuby

  # @!parse
  #   # Docker-based code executor for multi-language support.
  #   #
  #   # Docker executes agent-generated code in isolated containers with strict
  #   # resource limits. Supports Ruby, Python, JavaScript, and TypeScript.
  #   #
  #   # == Language Support
  #   # - Ruby: ruby:3.3-alpine
  #   # - Python: python:3.12-slim
  #   # - JavaScript: node:20-alpine
  #   # - TypeScript: node:20-alpine with tsx
  #   #
  #   # == Security Features
  #   # - Network isolation (--network=none)
  #   # - Memory limits and CPU quotas
  #   # - Read-only filesystem
  #   # - Dropped capabilities
  #   # - Sanitized environment
  #   #
  #   # @example Multi-language execution
  #   #   executor = DockerExecutor.new
  #   #   ruby_result = executor.execute("[1,2,3].sum", language: :ruby)
  #   #   python_result = executor.execute("sum([1,2,3])", language: :python)
  #   #
  #   # @see Executors::Docker For full documentation
  #   DockerExecutor = Executors::Docker
  DockerExecutor = Executors::Docker

  # @!parse
  #   # Ractor-based code executor for thread-safe isolation.
  #   #
  #   # Ractor executes code in isolated Ractor instances for true parallelism
  #   # with memory isolation. Each execution runs in its own Ractor with complete
  #   # memory separation from the caller.
  #   #
  #   # == Execution Modes
  #   # 1. **Isolated execution** (no tools) - Simple Ractor-based execution
  #   # 2. **Tool-supporting execution** (has tools) - Message-based tool calls
  #   #
  #   # == Features
  #   # - True parallelism (not limited by Global VM Lock)
  #   # - Complete memory isolation between executions
  #   # - Tool calls routed through safe message passing
  #   # - Operation limits via TracePoint
  #   #
  #   # @note Requires Ruby 3.0+ with Ractor support
  #   #
  #   # @example Basic execution
  #   #   executor = RactorExecutor.new
  #   #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
  #   #
  #   # @example With tools
  #   #   executor = RactorExecutor.new
  #   #   executor.send_tools("search" => search_tool)
  #   #   result = executor.execute('search(query: "Ruby")', language: :ruby)
  #   #
  #   # @see Executors::Ractor For full documentation
  #   RactorExecutor = Executors::Ractor
  RactorExecutor = Executors::Ractor
end
