module Smolagents
  module Concerns
    module GemLoader
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
