module Smolagents
  module Executors
    module RactorLazy
      # Comparison and conversion operators for ToolFuture.
      # All trigger resolution before delegating to the result.
      module FutureOperators
        def ==(other)
          _ensure_resolved!
          @result == other
        end

        def !=(other)
          _ensure_resolved!
          @result != other
        end

        # rubocop:disable Style/CaseEquality -- implementing case/when pattern matching support
        def ===(other)
          _ensure_resolved!
          @result === other
        end
        # rubocop:enable Style/CaseEquality

        def <=>(other)
          _ensure_resolved!
          @result <=> other
        end

        def to_s = _ensure_resolved! || @result.to_s
        def to_a = _ensure_resolved! || @result.to_a
        def to_h = _ensure_resolved! || @result.to_h
        def each(&) = _ensure_resolved! || @result.each(&)

        # Indifferent access: supports both hash[:key] and hash["key"] syntax.
        # LLMs trained on JSON use string keys, but Ruby code often uses symbols.
        # This tolerance prevents nil-access failures from key type mismatches.
        def [](key)
          _ensure_resolved!
          result = @result[key]
          # Try alternate key form for hash misses (symbol ↔ string)
          if result.nil? && @result.is_a?(::Hash) && @result.key?(key) == false
            alt_key = key.is_a?(::Symbol) ? key.to_s : key.to_s.to_sym
            result = @result[alt_key]
          end
          result
        end

        # rubocop:disable Style/OptionalBooleanParameter -- matching Ruby's respond_to? signature
        def respond_to?(method, include_private = false)
          # rubocop:enable Style/OptionalBooleanParameter
          return true if method.to_s.start_with?("_")
          return true if BUILTIN_METHODS.include?(method.to_sym)

          _ensure_resolved!
          @result.respond_to?(method, include_private)
        end

        def respond_to_missing?(method, include_private = false)
          return true if method.to_s.start_with?("_")

          _ensure_resolved!
          @result.respond_to?(method, include_private)
        end

        def method_missing(method, ...)
          _ensure_resolved!
          @result.public_send(method, ...)
        end

        BUILTIN_METHODS = %i[nil? is_a? kind_of? instance_of? class hash eql? empty? ! === <=>].freeze
      end
    end
  end
end
