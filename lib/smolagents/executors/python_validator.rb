# frozen_string_literal: true

module Smolagents
  # Python code validator using pattern matching.
  # Detects dangerous function calls, imports, and builtins.
  #
  # @example
  #   validator = PythonValidator.new
  #   validator.validate!("print('safe')") # OK
  #   validator.validate!("os.system('rm -rf /')") # raises InterpreterError
  class PythonValidator < Validator
    protected

    def dangerous_patterns
      [
        # Dangerous builtins
        /\beval\s*\(/,
        /\bexec\s*\(/,
        /\bcompile\s*\(/,
        /\b__import__\s*\(/,
        /\bopen\s*\(/,
        /\binput\s*\(/, # Can be used for RCE in some contexts

        # Dangerous module access
        /\bos\./,
        /\bsys\./,
        /\bsubprocess\./,
        /\bsocket\./,
        /\bshlex\./,
        /\bpickle\./,
        /\bmarshal\./,
        /\bimportlib\./,
        /\bbuiltins\./,
        /\b__builtins__/,

        # Code object access
        /\.func_code/,
        /\.func_globals/,
        /\.__code__/,
        /\.__globals__/,

        # Class manipulation
        /\.__class__/,
        /\.__bases__/,
        /\.__subclasses__/,
        /\.__mro__/,

        # Attribute access that could be dangerous
        /setattr\s*\(/,
        /getattr\s*\(/,
        /delattr\s*\(/,
        /hasattr\s*\(/, # Can trigger code execution via properties

        # Dunder methods that could be dangerous
        /\.__dict__/,
        /\.__init__/,
        /\.__del__/,
      ]
    end

    def dangerous_imports
      %w[
        os
        sys
        subprocess
        socket
        shlex
        pickle
        marshal
        importlib
        builtins
        __builtin__
        ctypes
        multiprocessing
        threading
        pty
        rlcompleter
      ]
    end

    def check_import(code, import)
      # Check for various import forms
      code.match?(/import\s+#{Regexp.escape(import)}\b/) ||
        code.match?(/from\s+#{Regexp.escape(import)}\s+import/)
    end
  end
end
