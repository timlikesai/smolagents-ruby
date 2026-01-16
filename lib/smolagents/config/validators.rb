module Smolagents
  module Config
    # Validation functions for configuration options.
    #
    # Each entry is a lambda that validates a configuration value and raises
    # ArgumentError if invalid. Used by {Configuration} to ensure configuration
    # integrity before use.
    #
    # Validators are called with the configuration value and should either:
    # - Return silently if valid
    # - Raise ArgumentError with a descriptive message if invalid
    #
    # @return [Hash{Symbol => Proc}] Validation lambdas for each configuration option
    # @api private
    #
    # @see Configuration For configuration management
    VALIDATORS = {
      log_format: ->(val) { %i[text json].include?(val) or raise ArgumentError, "log_format must be :text or :json" },
      log_level: lambda { |val|
        %i[debug info warn
           error].include?(val) or raise ArgumentError, "log_level must be :debug, :info, :warn, or :error"
      },
      max_steps: ->(val) { val.nil? || val.positive? or raise ArgumentError, "max_steps must be positive" },
      custom_instructions: lambda { |val|
        val.nil? || val.length <= 10_000 or raise ArgumentError, "custom_instructions too long (max 10,000 chars)"
      },
      search_provider: lambda { |val|
        SEARCH_PROVIDERS.include?(val) or raise ArgumentError,
                                                "search_provider must be one of: #{SEARCH_PROVIDERS.join(", ")}"
      },
      searxng_url: lambda { |val|
        return if val.nil?

        uri = URI.parse(val)
        (uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)) or raise ArgumentError,
                                                                 "searxng_url must be a valid HTTP(S) URL"
      }
    }.freeze
  end
end
