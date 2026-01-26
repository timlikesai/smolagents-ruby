module Smolagents
  module Tools
    module Support
      # Reusable message templates for tool results.
      #
      # Provides class-level DSL for defining common message patterns
      # that tools use to communicate results to agents.
      #
      # @example Defining messages at class level
      #   class MySearchTool < SearchTool
      #     include Support::ResultTemplates
      #
      #     empty_message "No results found."
      #     next_steps_message <<~MSG
      #       Try different search terms.
      #       Consider using a different tool.
      #     MSG
      #   end
      #
      # @example Using the defined messages
      #   def format_results(results)
      #     return empty_result_message if results.empty?
      #     # ... format results ...
      #     "#{formatted}\n\n#{next_steps_message}"
      #   end
      module ResultTemplates
        def self.included(base)
          base.extend(ClassMethods)
        end

        # Class methods for template DSL.
        module ClassMethods
          # Defines the message returned when results are empty.
          #
          # @param msg [String] The empty result message
          # @return [void]
          def empty_message(msg)
            define_method(:empty_result_message) { msg }
          end

          # Defines the next steps guidance message.
          #
          # @param msg [String] The next steps message
          # @return [void]
          def next_steps_message(msg)
            define_method(:next_steps_message) { msg }
          end

          # Defines the success header format.
          #
          # @param template [String] Template with %{count} and %{noun} placeholders
          # @return [void]
          def success_header(template)
            define_method(:success_header_template) { template }
          end
        end

        # Returns the empty result message, defaulting to a generic message.
        # @return [String]
        def empty_result_message
          "No results found."
        end

        # Returns the next steps message, defaulting to nil.
        # @return [String, nil]
        def next_steps_message
          nil
        end

        # Returns the success header template.
        # @return [String]
        def success_header_template
          "Found %<count>s %<noun>s"
        end

        # Formats a success header with the given count.
        #
        # @param count [Integer] Number of results
        # @param noun [String] Singular noun for results (default: "result")
        # @return [String] Formatted header
        def format_success_header(count, noun: "result")
          plural_noun = count == 1 ? noun : "#{noun}s"
          format(success_header_template, count:, noun: plural_noun)
        end
      end
    end
  end
end
