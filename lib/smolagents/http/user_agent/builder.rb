require_relative "../../version"

module Smolagents
  module Http
    class UserAgent
      # Builds RFC 7231 compliant User-Agent strings from components.
      #
      # Components are added in order:
      # 1. Agent name/version (optional)
      # 2. Library identifier (Smolagents/VERSION)
      # 3. Tool context (optional)
      # 4. Model identifier (optional)
      # 5. Ruby version
      # 6. Contact URL with bot indicator
      module Builder
        # Component configuration for User-Agent string building.
        # Each entry defines: [prefix, value_method, suffix, conditional]
        COMPONENTS = [
          { prefix: "", method: :agent_component, suffix: "", conditional: :agent_name },
          { prefix: "Smolagents/", method: :library_version, suffix: "", conditional: nil },
          { prefix: "Tool:", method: :tool_name, suffix: "", conditional: :tool_name },
          { prefix: "Model:", method: :model_id, suffix: "", conditional: :model_id },
          { prefix: "Ruby/", method: :ruby_version, suffix: "", conditional: nil },
          { prefix: "(+", method: :contact_url, suffix: "; bot)", conditional: nil }
        ].freeze

        # Builds the User-Agent string from component values.
        #
        # @param user_agent [UserAgent] The user agent instance
        # @return [String] RFC 7231 compliant User-Agent string
        def self.build(user_agent)
          COMPONENTS.filter_map { |comp| build_component(user_agent, comp) }.join(" ")
        end

        # Builds a single component if its condition is met.
        #
        # @param user_agent [UserAgent] The user agent instance
        # @param component [Hash] Component configuration
        # @return [String, nil] Component string or nil if conditional not met
        def self.build_component(user_agent, component)
          return nil if component[:conditional] && !user_agent.public_send(component[:conditional])

          value = resolve_value(user_agent, component[:method])
          "#{component[:prefix]}#{value}#{component[:suffix]}"
        end

        # Resolves the value for a component method.
        #
        # @param user_agent [UserAgent] The user agent instance
        # @param method [Symbol] Method to call
        # @return [String] The resolved value
        def self.resolve_value(user_agent, method)
          case method
          when :agent_component then "#{user_agent.agent_name}/#{user_agent.agent_version}"
          when :library_version then VERSION
          when :ruby_version then RUBY_VERSION
          else user_agent.public_send(method)
          end
        end

        private_class_method :build_component, :resolve_value
      end
    end
  end
end
