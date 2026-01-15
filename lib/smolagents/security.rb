require_relative "security/validation_types"
require_relative "security/allowlists"
require_relative "security/code_validator"
require_relative "security/prompt_sanitizer"
require_relative "security/secret_redactor"

module Smolagents
  # Security utilities for AI agent systems.
  #
  # This module provides tools for protecting against prompt injection attacks,
  # preventing accidental exposure of sensitive information, and validating
  # agent-generated code for safety.
  #
  # @example Validating agent code
  #   result = Smolagents::Security::CodeValidator.validate(code)
  #   result.valid? # => true/false
  #
  # @example Blocking unsafe code
  #   Smolagents::Security::CodeValidator.validate!(code)
  #   # Raises InterpreterError if dangerous code detected
  #
  # @example Sanitizing user input
  #   sanitized = Smolagents::Security::PromptSanitizer.sanitize(user_input)
  #   agent.run(sanitized)
  #
  # @example Redacting secrets from logs
  #   safe_output = Smolagents::Security::SecretRedactor.redact(api_response)
  #   logger.info("Response: #{safe_output}")
  #
  # @see Smolagents::Security::CodeValidator Static code analysis
  # @see Smolagents::Security::PromptSanitizer Prompt injection detection
  # @see Smolagents::Security::SecretRedactor API key and secret redaction
  module Security
  end
end
