module Smolagents
  module Builders
    module Support
      # Self-documenting introspection for builders.
      #
      # Provides `.available_methods` (class method) and `#summary` (instance method)
      # for runtime discovery of builder capabilities and current configuration state.
      #
      # Works with Metadata#register_method to auto-discover documented methods.
      #
      # @example Class-level introspection
      #   AgentBuilder.available_methods[:required]
      #   #=> [{ name: :model, description: "Set model (required)", required: true }]
      #
      #   AgentBuilder.method_documentation
      #   #=> "## Required\n  .model - Set model (required)\n..."
      #
      # @example Instance-level introspection
      #   builder = Smolagents.agent.tools(:search)
      #   builder.summary
      #   #=> { builder_type: "AgentBuilder", configured: {...}, missing_required: [:model], ready_to_build: false }
      #
      # @see Base::Metadata#register_method
      module Introspection
        def self.included(base)
          base.extend(ClassMethods)
        end

        # Class-level introspection methods.
        module ClassMethods
          # Returns all available builder methods grouped by category.
          #
          # Categories are :required and :optional based on registration metadata.
          # Aliases are excluded from the listing.
          #
          # @return [Hash{Symbol => Array<Hash>}] Methods grouped by category
          #
          # @example
          #   AgentBuilder.available_methods[:required]
          #   #=> [{ name: :model, description: "Set model (required)", required: true }]
          def available_methods
            return {} unless respond_to?(:registered_methods)

            methods = registered_methods.reject { |_, meta| meta[:alias_of] }
            grouped = methods.group_by { |_, meta| meta[:required] ? :required : :optional }
            grouped.transform_values do |entries|
              entries.map do |name, meta|
                { name:, description: meta[:description], required: meta[:required], aliases: meta[:aliases] }
              end
            end
          end

          # Returns formatted documentation of all available methods.
          #
          # @return [String] Multi-line documentation string
          def method_documentation
            available_methods.flat_map do |category, methods|
              ["## #{category.to_s.capitalize}",
               *methods.map { "  .#{it[:name]} - #{it[:description]}" }]
            end.join("\n")
          end
        end

        # Returns current builder state for introspection.
        #
        # @return [Hash] Builder state with keys:
        #   - :builder_type [String] - Class name without module prefix
        #   - :configured [Hash] - Current configuration (values summarized)
        #   - :missing_required [Array<Symbol>] - Required methods not yet called
        #   - :ready_to_build [Boolean] - True if all requirements satisfied
        def summary
          {
            builder_type: self.class.name.split("::").last,
            configured: summarize_configuration,
            missing_required: missing_required_fields,
            ready_to_build: ready_to_build?
          }
        end

        # Check if builder has all required configuration.
        #
        # @return [Boolean] True if ready to call #build
        def ready_to_build? = missing_required_fields.empty?

        # Readable REPL output for builders.
        #
        # @return [String] Compact representation showing configuration state
        def inspect
          type = self.class.name.split("::").last
          ready = ready_to_build? ? "ready" : "needs: #{missing_required_fields.join(", ")}"
          items = inspect_config_items

          "#<#{type} #{items} (#{ready})>"
        end

        # List required fields that haven't been configured.
        #
        # @return [Array<Symbol>] Missing required method names
        def missing_required_fields
          return [] unless self.class.respond_to?(:registered_methods)

          self.class.registered_methods
              .select { |_, meta| meta[:required] && !meta[:alias_of] }
              .keys
              .reject { |name| field_configured?(name) }
        end

        private

        # Extract first 4 config items for compact inspect output.
        # @return [String] Formatted configuration items
        def inspect_config_items
          cfg = summarize_configuration.except(:__frozen__)
          items = cfg.first(4).map { |k, v| "#{k}=#{v}" }.join(" ")
          cfg.size > 4 ? "#{items} ..." : items
        end

        # Check if a field has been configured.
        #
        # @param name [Symbol] Field name to check
        # @return [Boolean] True if field has a value
        def field_configured?(name)
          cfg = respond_to?(:configuration) ? configuration : (@config || {})
          config_key = field_to_config_key(name)
          return false unless cfg.key?(config_key)

          value = cfg[config_key]
          return !value.empty? if value.respond_to?(:empty?)

          !value.nil?
        end

        # Map method name to configuration key.
        #
        # Override in builders with non-standard mappings. Default returns
        # the name unchanged. Each builder can override for its specific mappings.
        #
        # @param name [Symbol] Method name
        # @return [Symbol] Configuration key
        def field_to_config_key(name) = name

        # Summarize configuration values for display output.
        #
        # Compacts empty values and transforms complex types to readable summaries.
        #
        # @return [Hash] Configuration with values summarized for readability
        def summarize_configuration
          cfg = respond_to?(:configuration) ? configuration : (@config || {})
          cfg.compact.transform_values { |v| summarize_value(v) }
        end

        # Convert a configuration value to display-friendly format.
        #
        # Converts procs to "<block>", large arrays to "[N items]", etc.
        #
        # @param value [Object] Any configuration value
        # @return [String] Human-readable representation
        # rubocop:disable Metrics/CyclomaticComplexity -- case statement for type dispatch
        def summarize_value(value)
          case value
          when Proc then "<block>"
          when Array then value.empty? ? "[]" : "[#{value.size} items]"
          when Hash then value.empty? ? "{}" : "{#{value.size} keys}"
          when String then value.length > 50 ? "#{value[0, 47]}..." : value
          else value.to_s
          end
        end
        # rubocop:enable Metrics/CyclomaticComplexity
      end
    end
  end
end
