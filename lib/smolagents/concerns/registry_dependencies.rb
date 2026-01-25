module Smolagents
  module Concerns
    module Registry
      # Dependency tracking and graph operations for the concern registry.
      #
      # Provides methods for querying dependency relationships between
      # concerns and validating the registry for missing dependencies.
      #
      # @see Registry For concern registration and querying
      module Dependencies
        # Returns all transitive dependencies for a concern.
        # @param name [Symbol] Concern name
        # @return [Array<Symbol>] All dependencies (direct and transitive)
        def dependencies_for(name)
          concern = @concerns[name]
          return [] unless concern

          visited = Set.new
          collect_dependencies(concern.dependencies, visited)
          visited.to_a
        end

        # Returns all concerns that depend on the given concern.
        # @param name [Symbol] Concern name
        # @return [Array<Symbol>] Names of dependent concerns
        def dependents_of(name)
          @concerns.select { |_, info| info.dependencies.include?(name) }.keys
        end

        # Returns concerns with no dependencies.
        # @return [Array<Symbol>] Standalone concern names
        def standalone = @concerns.select { _2.dependencies.empty? }.keys

        # Returns concerns that have dependencies.
        # @return [Array<Symbol>] Dependent concern names
        def dependent = @concerns.reject { _2.dependencies.empty? }.keys

        # Returns the dependency graph as a hash for visualization.
        # @return [Hash{Symbol => Hash}] Graph with :depends_on and :depended_by
        def graph
          @concerns.transform_values do |info|
            { depends_on: info.dependencies, depended_by: dependents_of(info.name) }
          end
        end

        # Validates the registry for missing dependencies.
        # @return [Hash{Symbol => Array<Symbol>}] Missing dependencies by concern
        def validate
          missing = {}
          @concerns.each do |name, info|
            unregistered = info.dependencies.reject { @concerns.key?(it) }
            missing[name] = unregistered if unregistered.any?
          end
          missing
        end

        private

        def collect_dependencies(deps, visited)
          deps.each do |dep|
            next if visited.include?(dep)

            visited << dep
            concern = @concerns[dep]
            collect_dependencies(concern.dependencies, visited) if concern
          end
        end
      end
    end
  end
end
