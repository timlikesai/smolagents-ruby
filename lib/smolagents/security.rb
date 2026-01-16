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
  #   result = Smolagents::Security::CodeValidator.validate("puts 'hello'")
  #   result.valid?  #=> true
  #
  # @example Blocking unsafe code
  #   result = Smolagents::Security::CodeValidator.validate("system('rm -rf /')")
  #   result.valid?  #=> false
  #
  # @example Sanitizing user input
  #   Smolagents::Security::PromptSanitizer.sanitize("normal query").include?("normal")  #=> true
  #
  # @example Redacting secrets from logs
  #   Smolagents::Security::SecretRedactor.redact("key: sk-12345678901234567890abcdef").include?("[REDACTED]")  #=> true
  #
  # @see Smolagents::Security::CodeValidator Static code analysis
  # @see Smolagents::Security::PromptSanitizer Prompt injection detection
  # @see Smolagents::Security::SecretRedactor API key and secret redaction
  module Security
  end
end
