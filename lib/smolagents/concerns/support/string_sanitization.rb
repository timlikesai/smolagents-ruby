module Smolagents
  module Concerns
    module Support
      # UTF-8 string sanitization for handling malformed external API responses.
      #
      # Shared by HTTP response handling and JSON parsing modules to ensure
      # consistent sanitization of strings that may contain invalid UTF-8 bytes.
      #
      # @example Include in a module or class
      #   class MyApiClient
      #     include Smolagents::Concerns::Support::StringSanitization
      #
      #     def fetch(url)
      #       response = http_get(url)
      #       sanitize_utf8(response.body)
      #     end
      #   end
      #
      # @see Http::ResponseHandling Uses for HTTP response body sanitization
      # @see Concerns::Json Uses for JSON parsing sanitization
      module StringSanitization
        # Sanitize string to valid UTF-8.
        #
        # Replaces invalid/undefined bytes with the Unicode replacement character.
        # Returns empty string for nil input.
        #
        # @param string [String, nil] String to sanitize
        # @return [String] Valid UTF-8 string
        # @example
        #   sanitize_utf8(nil)           # => ""
        #   sanitize_utf8("valid")       # => "valid"
        #   sanitize_utf8("\xFF\xFE")    # => "\uFFFD\uFFFD"
        def sanitize_utf8(string)
          return "" if string.nil?

          string.encode("UTF-8", invalid: :replace, undef: :replace, replace: "\uFFFD")
        end
      end
    end
  end
end
