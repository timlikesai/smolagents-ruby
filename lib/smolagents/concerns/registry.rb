require_relative "registry_documentation"
require_relative "registry_dependencies"

module Smolagents
  module Concerns
    # Self-documenting registry tracking all concerns and their relationships.
    #
    # Provides auto-registration, dependency tracking, and introspection.
    #
    # @see ConcernInfo For concern metadata structure
    # @see Documentation For markdown documentation generation
    # @see Dependencies For dependency tracking and validation
    module Registry
      extend Documentation
      extend Dependencies

      # Immutable concern metadata container.
      ConcernInfo = Data.define(:name, :module_path, :dependencies, :provides, :category, :description) do
        def to_h = { name:, module_path:, dependencies:, provides:, category:, description: }

        def deconstruct_keys(_) = to_h
      end

      @concerns = {}
      @mutex = Mutex.new

      class << self
        attr_reader :concerns

        # Registers a concern with metadata.
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
        def [](name) = @concerns[name]

        # Lists all registered concern names.
        def all = @concerns.keys

        # Groups concerns by category.
        def by_category = @concerns.values.group_by(&:category)

        # Returns all concerns in a specific category.
        def in_category(category) = @concerns.values.select { it.category == category }

        # Clears all registered concerns (useful for testing).
        def reset!
          @mutex.synchronize { @concerns.clear }
        end

        private

        def extract_provides(module_ref)
          return [] unless module_ref.is_a?(Module)

          module_ref.public_instance_methods(false)
        rescue StandardError
          []
        end

        def extract_description(module_ref)
          return nil unless module_ref.is_a?(Module)

          nil
        end
      end
    end
  end
end
