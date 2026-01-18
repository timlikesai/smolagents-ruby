module Smolagents
  module Concerns
    # Self-documenting registry tracking all concerns and their relationships.
    #
    # Provides auto-registration, dependency tracking, introspection, and
    # automatic documentation generation for the concern system.
    #
    # @example Registering a concern
    #   Registry.register :rate_limiter,
    #     Concerns::RateLimiter,
    #     category: :resilience,
    #     provides: %i[enforce_rate_limit! rate_limit_available?],
    #     description: "API rate limiting with configurable cooldown"
    #
    # @example Querying dependencies
    #   Registry.dependencies_for(:resilience)
    #   #=> [:circuit_breaker, :rate_limiter]
    #
    # @example Generating documentation
    #   puts Registry.documentation
    #
    # @see ConcernInfo For concern metadata structure
    module Registry
      # Immutable concern metadata container.
      #
      # @!attribute [r] name
      #   @return [Symbol] Unique identifier for the concern
      # @!attribute [r] module_path
      #   @return [String] Full module path (e.g., "Smolagents::Concerns::RateLimiter")
      # @!attribute [r] dependencies
      #   @return [Array<Symbol>] Names of concerns this concern depends on
      # @!attribute [r] provides
      #   @return [Array<Symbol>] Public methods provided by this concern
      # @!attribute [r] category
      #   @return [Symbol] Concern category (:agents, :tools, :resilience, etc.)
      # @!attribute [r] description
      #   @return [String, nil] Human-readable description
      ConcernInfo = Data.define(:name, :module_path, :dependencies, :provides, :category, :description) do
        def to_h = { name:, module_path:, dependencies:, provides:, category:, description: }

        def deconstruct_keys(_) = to_h
      end

      @concerns = {}
      @mutex = Mutex.new

      class << self
        attr_reader :concerns

        # Registers a concern with metadata.
        #
        # @param name [Symbol] Unique identifier for the concern
        # @param module_ref [Module] The concern module
        # @param dependencies [Array<Symbol>] Concerns this depends on
        # @param provides [Array<Symbol>] Public methods provided
        # @param category [Symbol] Concern category
        # @param description [String, nil] Human-readable description
        # @return [ConcernInfo] The registered concern info
        def register(name, module_ref, dependencies: [], provides: [], category: :general, description: nil)
          info = ConcernInfo.new(
            name:,
            module_path: module_ref.respond_to?(:name) ? module_ref.name : module_ref.to_s,
            dependencies: Array(dependencies),
            provides: provides.any? ? provides : extract_provides(module_ref),
            category:,
            description: description || extract_description(module_ref)
          )
          @mutex.synchronize { @concerns[name] = info }
          info
        end

        # Retrieves concern info by name.
        # @param name [Symbol] Concern name
        # @return [ConcernInfo, nil] Concern info or nil if not found
        def [](name) = @concerns[name]

        # Lists all registered concern names.
        # @return [Array<Symbol>] All concern names
        def all = @concerns.keys

        # Groups concerns by category.
        # @return [Hash{Symbol => Array<ConcernInfo>}] Concerns grouped by category
        def by_category = @concerns.values.group_by(&:category)

        # Returns all concerns in a specific category.
        # @param category [Symbol] Category to filter by
        # @return [Array<ConcernInfo>] Concerns in that category
        def in_category(category) = @concerns.values.select { it.category == category }

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

        # Generates markdown documentation for all concerns.
        # @return [String] Formatted documentation
        def documentation
          by_category.map do |category, concern_infos|
            category_doc(category, concern_infos)
          end.join("\n---\n\n")
        end

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

        # Clears all registered concerns (useful for testing).
        # @return [void]
        def reset!
          @mutex.synchronize { @concerns.clear }
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

        def extract_provides(module_ref)
          return [] unless module_ref.is_a?(Module)

          module_ref.public_instance_methods(false)
        rescue StandardError
          []
        end

        def extract_description(module_ref)
          return nil unless module_ref.is_a?(Module)

          # Try to extract from source comments if YARD is available
          nil
        end

        def category_doc(category, concern_infos)
          <<~DOC
            ## #{titleize(category)}

            #{concern_infos.map { concern_doc(it) }.join("\n\n")}
          DOC
        end

        def concern_doc(info)
          deps = info.dependencies.any? ? info.dependencies.join(", ") : "None"
          provides = info.provides.any? ? info.provides.join(", ") : "None"
          <<~DOC.strip
            ### #{info.name}
            #{info.description || "No description"}

            **Module:** `#{info.module_path}`
            **Provides:** #{provides}
            **Dependencies:** #{deps}
          DOC
        end

        def titleize(sym)
          sym.to_s.split("_").map(&:capitalize).join(" ")
        end
      end
    end
  end
end
