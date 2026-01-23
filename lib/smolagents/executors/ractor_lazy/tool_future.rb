module Smolagents
  module Executors
    module RactorLazy
      # Lazy tool result - yields on access for batching.
      #
      # Inherits from BasicObject to intercept all method calls.
      # Any access triggers batch resolution via Fiber.yield.
      #
      class ToolFuture < BasicObject
        attr_reader :tool_name, :args, :kwargs

        def initialize(tool_name, args, kwargs, batch)
          @tool_name = tool_name
          @args = args
          @kwargs = kwargs
          @batch = batch
          @resolved = false
          @result = nil
          @error = nil
          batch << self
        end

        # Resolution API (used by BatchHandling)
        def _resolve!(value)
          @result = value
          @resolved = true
        end

        def _reject!(error)
          @error = error
          @resolved = true
        end

        def _resolved? = @resolved
        def _result = @result
        def _error = @error
        def _pending? = !@resolved
        def _future? = true

        # Identity methods that don't trigger resolution
        def nil? = false
        def is_a?(klass) = [ToolFuture, ::BasicObject].include?(klass)
        def kind_of?(klass) = is_a?(klass)
        def instance_of?(klass) = klass == ToolFuture
        def class = ToolFuture

        # rubocop:disable Style/OptionalBooleanParameter -- matches Ruby's respond_to? signature
        def respond_to?(method, include_private = false)
          # rubocop:enable Style/OptionalBooleanParameter
          return true if method.to_s.start_with?("_")
          return true if %i[nil? is_a? kind_of? instance_of? class].include?(method.to_sym)

          _ensure_resolved!
          @result.respond_to?(method, include_private)
        end

        def respond_to_missing?(method, include_private = false)
          return true if method.to_s.start_with?("_")

          _ensure_resolved!
          @result.respond_to?(method, include_private)
        end

        # Delegate all methods to resolved value
        def method_missing(method, ...)
          _ensure_resolved!
          @result.public_send(method, ...)
        end

        # Common methods that trigger resolution
        def ==(other)
          _ensure_resolved!
          @result == other
        end

        def to_s = _ensure_resolved! || @result.to_s
        def to_a = _ensure_resolved! || @result.to_a
        def to_h = _ensure_resolved! || @result.to_h
        def each(&) = _ensure_resolved! || @result.each(&)
        def [](key) = _ensure_resolved! || @result[key]

        def inspect
          return "#<Future:pending #{@tool_name}>" unless @resolved

          "#<Future:resolved #{@tool_name} => #{@result.inspect[0, 50]}>"
        end

        private

        def _ensure_resolved!
          return if @resolved

          pending = @batch.select(&:_pending?)
          ::Fiber.yield({ type: :batch, futures: pending })

          ::Kernel.raise "Future not resolved after batch" unless @resolved
          ::Kernel.raise @error if @error
        end
      end
    end
  end
end
