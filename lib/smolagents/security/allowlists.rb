module Smolagents
  module Security
    # Defines dangerous methods, constants, patterns, and imports for code validation.
    #
    # These sets and arrays define what operations are forbidden in agent-generated
    # Ruby code to prevent security vulnerabilities.
    module Allowlists
      # Methods forbidden in agent code. Prevents:
      # - Arbitrary code execution (eval, system, exec)
      # - Process modification (fork, exit)
      # - Resource access (require, load)
      # - Object introspection (send, method, const_get)
      DANGEROUS_METHODS = Set.new(%w[
                                    eval instance_eval class_eval module_eval system exec spawn fork
                                    require require_relative load autoload open File IO Dir
                                    send __send__ public_send method define_method const_get const_set remove_const
                                    class_variable_get class_variable_set remove_class_variable
                                    instance_variable_get instance_variable_set remove_instance_variable
                                    binding ObjectSpace Marshal Kernel
                                    exit exit! abort trap at_exit
                                  ]).freeze

      # Constants forbidden in agent code. Prevents direct access to:
      # - Filesystem (File, IO, Dir)
      # - Process control (Process, Thread, Signal)
      # - Environment (ENV, ARGV)
      # - Object manipulation (ObjectSpace, Marshal)
      DANGEROUS_CONSTANTS = Set.new(%w[
                                      File IO Dir Process Thread ObjectSpace Marshal Kernel ENV Signal
                                      FileUtils Pathname Socket TCPSocket UDPSocket BasicSocket
                                      ARGV ARGF DATA RUBY_PLATFORM RUBY_VERSION
                                    ]).freeze

      # Regex patterns for detecting command execution syntax.
      # Matches backticks and %x{} percent literals.
      DANGEROUS_PATTERNS = [/`[^`]+`/, /%x\[/, /%x\{/, /%x\(/].freeze

      # Module names forbidden in require statements.
      # These would bypass sandbox restrictions.
      DANGEROUS_IMPORTS = %w[FileUtils net/http open-uri socket].freeze

      # Sexp node types containing identifiers in Ruby AST.
      IDENTIFIER_TYPES = %i[@ident @const].freeze

      # Maximum depth for AST traversal to prevent stack overflow.
      MAX_AST_DEPTH = 100
    end
  end
end
