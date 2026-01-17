require_relative "support/gem_loader"
require_relative "support/browser_mode"

module Smolagents
  module Concerns
    # Standalone support concerns for infrastructure tasks.
    #
    # @!group Concern Dependency Graph
    #
    # == Dependency Matrix
    #
    #   | Concern     | Depends On | Depended By      | Auto-Includes |
    #   |-------------|------------|------------------|---------------|
    #   | GemLoader   | -          | Browser, various | -             |
    #   | BrowserMode | -          | Http, Browser    | -             |
    #
    # == Sub-concern Methods
    #
    #   GemLoader
    #       +-- require_gem(name, version: nil) - Load gem with version check
    #       +-- gem_available?(name) - Check if gem is installed
    #       +-- lazy_require(name, &block) - Load gem on first use
    #
    #   BrowserMode
    #       +-- browser_headers - Get headers mimicking a browser
    #       +-- user_agent - Get a realistic user agent string
    #       +-- accept_headers - Get typical Accept headers
    #
    # == No Instance Variables
    #
    # Both support concerns are stateless utility modules.
    #
    # == No External Dependencies
    #
    # These concerns use only Ruby stdlib.
    #
    # @!endgroup
    #
    # @see GemLoader For dynamic gem loading
    # @see BrowserMode For browser-like HTTP request headers
    module Support
    end
  end
end
