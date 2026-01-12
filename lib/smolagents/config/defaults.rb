module Smolagents
  module Config
    AUTHORIZED_IMPORTS = %w[json uri net/http time date set base64].freeze

    DEFAULTS = {
      max_steps: 20,
      custom_instructions: nil,
      authorized_imports: AUTHORIZED_IMPORTS,
      audit_logger: nil,
      log_format: :text,
      log_level: :info
    }.freeze
  end
end
