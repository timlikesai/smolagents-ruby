module Smolagents
  module Concerns
    module Resilience
      # Fallback strategy that considers server capabilities.
      #
      # Builds fallback chains based on required capabilities and handles
      # capability mismatches by routing to compatible endpoints.
      #
      # @example Build a capability-aware fallback chain
      #   include CapabilityAwareFallback
      #
      #   fallbacks = build_capability_aware_fallbacks(
      #     endpoints: available_endpoints,
      #     required_capabilities: [:supports_tools]
      #   )
      #
      # @example Handle capability failure
      #   next_endpoint = handle_capability_failure(
      #     error: the_error,
      #     current_endpoint: current,
      #     fallback_chain: chain
      #   )
      #
      # @see CapabilityDetection
      module CapabilityAwareFallback
        include CapabilityDetection

        # Build fallback chain based on required capabilities.
        #
        # Filters endpoints to only those that support all required capabilities,
        # then sorts by priority.
        #
        # @param endpoints [Array] Available endpoints
        # @param required_capabilities [Array<Symbol>] Required capability names
        # @return [Array] Compatible endpoints sorted by priority
        def build_capability_aware_fallbacks(endpoints:, required_capabilities: [])
          compatible = endpoints.select do |ep|
            url = ep.respond_to?(:url) ? ep.url : ep[:url]
            server_type = ep.respond_to?(:server_type) ? ep.server_type : ep[:server_type]

            capabilities = detect_capabilities(base_url: url, server_type:)
            meets_requirements?(capabilities, required_capabilities)
          end

          compatible.sort_by do |ep|
            ep.respond_to?(:priority) ? ep.priority : (ep[:priority] || 99)
          end
        end

        # Handle capability failure with intelligent retry.
        #
        # Learns from the error, then finds the next endpoint in the chain
        # that supports the failed feature.
        #
        # @param error [Exception] The error that occurred
        # @param current_endpoint [Object] Current endpoint
        # @param fallback_chain [Array] Available fallback endpoints
        # @return [Object, nil] Next compatible endpoint or nil
        def handle_capability_failure(error:, current_endpoint:, fallback_chain:)
          current_url = endpoint_url(current_endpoint)
          feature = extract_failed_feature(error)

          learn_from_error(base_url: current_url, error:, attempted_feature: feature)

          next_endpoint = fallback_chain.find do |ep|
            next if same_endpoint?(ep, current_endpoint)

            caps = detect_capabilities(base_url: endpoint_url(ep))
            caps.public_send(feature)
          end

          emit_fallback_triggered(current_endpoint, next_endpoint, feature) if next_endpoint
          next_endpoint
        end

        # Check if an error is a capability mismatch.
        #
        # @param error [Exception] The error to check
        # @return [Boolean]
        def capability_mismatch?(error)
          return false unless error.respond_to?(:response)

          status = error.response&.dig(:status) || error.response&.dig("status")
          return false unless status == 400

          message = error.message.to_s.downcase
          capability_patterns.any? { |pattern| message.match?(pattern) }
        end

        private

        def meets_requirements?(capabilities, requirements)
          requirements.all? do |req|
            capability_name = req.to_s.start_with?("supports_") ? req : :"supports_#{req}"
            capabilities.public_send(capability_name)
          end
        end

        def extract_failed_feature(error)
          message = error.message.to_s.downcase
          case message
          when /response_format|json_mode|json/ then :supports_json_mode
          when /stop/ then :supports_stop_array
          else :supports_tools # Default - covers tools/function keywords and unknown errors
          end
        end

        def endpoint_url(endpoint)
          endpoint.respond_to?(:url) ? endpoint.url : endpoint[:url]
        end

        def same_endpoint?(ep1, ep2) = endpoint_url(ep1) == endpoint_url(ep2)

        def emit_fallback_triggered(from, to, feature)
          return unless respond_to?(:emit, true)

          from_name = from.respond_to?(:name) ? from.name : from[:name]
          to_name = to.respond_to?(:name) ? to.name : to[:name]

          emit :capability_event, phase: :fallback,
                                  from_endpoint: from_name,
                                  to_endpoint: to_name,
                                  missing_capability: feature
        end

        def capability_patterns
          @capability_patterns ||= [
            /unknown.*parameter/i,
            /unsupported.*field/i,
            /unexpected.*key/i,
            /invalid.*option/i,
            /response_format.*not.*supported/i,
            /tools.*not.*available/i,
            /not.*supported/i,
            /unrecognized.*request/i
          ].freeze
        end
      end
    end
  end
end
