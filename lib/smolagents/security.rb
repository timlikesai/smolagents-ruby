require_relative "security/prompt_sanitizer"
require_relative "security/secret_redactor"

module Smolagents
  # Security utilities for AI agent systems.
  #
  # This module provides tools for protecting against prompt injection attacks
  # and preventing accidental exposure of sensitive information in logs and outputs.
  #
  # @example Sanitizing user input
  #   sanitized = Smolagents::Security::PromptSanitizer.sanitize(user_input)
  #   agent.run(sanitized)
  #
  # @example Blocking suspicious prompts
  #   Smolagents::Security::PromptSanitizer.validate!(user_input)
  #   # Raises PromptInjectionError if injection detected
  #
  # @example Redacting secrets from logs
  #   safe_output = Smolagents::Security::SecretRedactor.redact(api_response)
  #   logger.info("Response: #{safe_output}")
  #
  # @see Smolagents::Security::PromptSanitizer Prompt injection detection
  # @see Smolagents::Security::SecretRedactor API key and secret redaction
  module Security
  end
end
