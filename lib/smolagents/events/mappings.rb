module Smolagents
  module Events
    # Maps event class names to event classes via auto-registration.
    #
    # Each `define_event` call auto-registers the class. Symbol names are
    # derived from class names via snake_case convention (e.g., StepCompleted → :step_completed).
    #
    # Legacy symbol aliases (e.g., :step_complete → StepCompleted) are maintained
    # for backward compatibility during migration.
    #
    # @example Resolving names to classes
    #   Mappings.resolve(:step_completed)  # => StepCompleted
    #   Mappings.resolve(StepCompleted)    # => StepCompleted (pass-through)
    #
    # @example Checking valid names
    #   Mappings.valid?(:step_completed)   # => true
    #   Mappings.valid?(:unknown)          # => false
    #
    # @see Consumer For event handler registration
    # @see Emitter For event emission
    module Mappings
      @events = {}
      @aliases = {}

      class << self
        # Register an event class by its convention-derived name.
        #
        # @param klass [Class] Event class with .event_name method
        def register(klass) = @events[klass.event_name.to_sym] = klass

        # Register a legacy alias for backward compatibility.
        #
        # @param alias_name [Symbol] Legacy name
        # @param canonical_name [Symbol] Convention-derived name
        def register_alias(alias_name, canonical_name) = @aliases[alias_name] = canonical_name

        # Resolves a name or class to an event class.
        #
        # @param name_or_class [Symbol, Class] Event name or class
        # @return [Class] The resolved event class
        # @raise [ArgumentError] If name is unknown
        def resolve(name_or_class)
          return name_or_class if name_or_class.is_a?(Class)

          canonical = @aliases.fetch(name_or_class, name_or_class)
          klass = @events[canonical]
          raise ArgumentError, "Unknown event: #{name_or_class}. Valid: #{names.join(", ")}" unless klass

          klass
        end

        # Checks if a name or class is a valid event identifier.
        #
        # @param name_or_class [Symbol, Class] Name or class to check
        # @return [Boolean]
        def valid?(name_or_class)
          return true if name_or_class.is_a?(Class)

          canonical = @aliases.fetch(name_or_class, name_or_class)
          @events.key?(canonical)
        end

        # @return [Array<Symbol>] All valid event names (canonical + aliases)
        def names = @events.keys + @aliases.keys

        # @return [Array<Class>] All event classes
        def classes = @events.values

        # @api private
        def clear!
          @events.clear
          @aliases.clear
        end

        # @api private — For testing only
        def canonical_names = @events.keys

        # @api private — For testing only
        def alias_names = @aliases.keys
      end
    end
  end
end
