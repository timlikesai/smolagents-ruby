module Smolagents
  class RubyValidator < Validator
    include Concerns::RubySafety

    def validate(code)
      errors = []
      begin
        validate_ruby_code!(code)
      rescue InterpreterError => e
        errors << e.message
      end
      ValidationResult.new(valid: errors.empty?, errors: errors, warnings: [])
    end

    def validate!(code)
      validate_ruby_code!(code)
    end
  end
end
