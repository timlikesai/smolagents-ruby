module Smolagents
  #
  class PythonValidator < Validator
    protected

    def dangerous_patterns
      [
        /\beval\s*\(/,
        /\bexec\s*\(/,
        /\bcompile\s*\(/,
        /\b__import__\s*\(/,
        /\bopen\s*\(/,
        /\binput\s*\(/, # Can be used for RCE in some contexts

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

        /\.func_code/,
        /\.func_globals/,
        /\.__code__/,
        /\.__globals__/,

        /\.__class__/,
        /\.__bases__/,
        /\.__subclasses__/,
        /\.__mro__/,

        /setattr\s*\(/,
        /getattr\s*\(/,
        /delattr\s*\(/,
        /hasattr\s*\(/, # Can trigger code execution via properties

        /\.__dict__/,
        /\.__init__/,
        /\.__del__/
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
      code.match?(/import\s+#{Regexp.escape(import)}\b/) ||
        code.match?(/from\s+#{Regexp.escape(import)}\s+import/)
    end
  end
end
