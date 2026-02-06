module Smolagents
  module Testing
    module ModelCapabilities
      # Formatting helpers for model capability display.
      #
      # Provides table formatting and human-readable representations.
      module Formatters
        # Get header line for table display.
        # @return [String] Formatted table header row
        def self.header_line
          [
            "Model".ljust(30), "Context".rjust(8),
            "Reason".ljust(8), "V", "T", "Architecture".ljust(12)
          ].join(" | ")
        end

        # Instance methods for Capability
        module InstanceMethods
          # Get summary line for table display.
          # @return [String] Formatted single-line summary row
          def summary_line
            [
              model_id.ljust(30), context_length.to_s.rjust(8),
              reasoning.to_s.ljust(8), vision? ? "V" : "-", tool_use? ? "T" : "-",
              architecture.to_s.ljust(12)
            ].join(" | ")
          end
        end
      end
    end
  end
end
