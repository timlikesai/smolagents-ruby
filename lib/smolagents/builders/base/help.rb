module Smolagents
  module Builders
    module Base
      # Help text generation for REPL-friendly builder introspection.
      #
      # @see Metadata#register_method Define method metadata for help
      module Help
        # Show help for this builder.
        #
        # @return [String] Formatted help text showing methods and current state
        def help
          parts = [
            "\n#{self.class.name} - Available Methods\n",
            ("=" * 60)
          ]

          parts.concat(help_methods_section)
          parts.concat(help_footer_section)

          parts.join("\n")
        end

        private

        # @return [Array<String>] Methods section lines
        def help_methods_section
          parts = []
          parts.concat(format_method_group("Required", required_registered_methods)) if required_registered_methods.any?
          parts.concat(format_method_group("Optional", optional_registered_methods)) if optional_registered_methods.any?
          parts
        end

        def required_registered_methods
          self.class.registered_methods.select { |_, meta| meta[:required] && !meta[:alias_of] }
        end

        def optional_registered_methods
          self.class.registered_methods.reject { |_, meta| meta[:required] || meta[:alias_of] }
        end

        # @param label [String] Group label
        # @param methods [Hash<Symbol, Hash>] Methods to format
        # @return [Array<String>] Formatted lines
        def format_method_group(label, methods)
          lines = ["\n#{label}:"]
          methods.each do |name, meta|
            aliases_str = meta[:aliases].any? ? " (aliases: #{meta[:aliases].join(", ")})" : ""
            lines << "  .#{name}#{aliases_str}"
            lines << "    #{meta[:description]}"
          end
          lines
        end

        # @return [Array<String>] Footer section lines
        def help_footer_section
          [
            "\nCurrent Configuration:", "  #{inspect}",
            "\nPattern Matching:", "  case builder",
            "  in #{self.class.name}[#{data_define_attributes}]", "    # Match and destructure", "  end",
            "\nBuild:", "  .build - Create the configured object", ""
          ]
        end

        # @return [String] Comma-separated attribute pattern
        def data_define_attributes
          self.class.ancestors.find { |a| a.is_a?(Class) && a.superclass == Data }
              &.members&.join(", ") || "..."
        end
      end
    end
  end
end
