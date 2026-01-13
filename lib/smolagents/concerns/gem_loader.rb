module Smolagents
  module Concerns
    # Gem dependency loading with helpful error messages
    #
    # Provides a convenient way to require gems with automatic error messages
    # suggesting how to add them to the Gemfile if missing.
    #
    # @example Basic usage
    #   require_gem("nokogiri")
    #   # Raises LoadError with friendly message if missing
    #
    # @example With custom name and version
    #   require_gem("openai", install_name: "ruby-openai", version: "~> 4.0")
    #   # Error message: ruby-openai gem required. Add `gem 'ruby-openai', '~> 4.0'` to your Gemfile.
    #
    # @see MCP Which uses this for optional dependencies
    module GemLoader
      # Require a gem with a helpful error message
      #
      # Attempts to require the gem and provides a user-friendly error message
      # with the exact Gemfile addition if it's missing.
      #
      # @param name [String] Gem name (used as require path)
      # @param install_name [String, nil] Display name for error message (defaults to name)
      # @param version [String, nil] Version constraint (e.g., "~> 4.0")
      # @param description [String, nil] Human description (defaults to "name gem")
      # @return [void]
      # @raise [LoadError] With Gemfile suggestion if gem not available
      # @example Requiring with version constraint
      #   require_gem("mcp", version: "~> 0.5")
      def require_gem(name, install_name: nil, version: nil, description: nil)
        require name
      rescue LoadError
        gem_name = install_name || name
        desc = description || "#{gem_name} gem"
        version_spec = version ? ", '#{version}'" : ""
        raise LoadError, "#{desc} required. Add `gem '#{gem_name}'#{version_spec}` to your Gemfile."
      end
    end
  end
end
