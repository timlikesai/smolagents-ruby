module Smolagents
  module Executors
    module RactorLazy
      # Identity and type-checking methods for ToolFuture.
      # These methods trigger resolution so conditionals work correctly.
      module FutureIdentity
        def nil?
          return @result.nil? if @resolved

          _ensure_resolved!
          @result.nil?
        rescue ::FiberError
          false
        end

        def is_a?(klass)
          return true if [ToolFuture, ::BasicObject].include?(klass)
          return @result.is_a?(klass) if @resolved

          _ensure_resolved!
          @result.is_a?(klass)
        rescue ::FiberError
          false
        end

        def kind_of?(klass) = is_a?(klass)

        def instance_of?(klass)
          return true if klass == ToolFuture
          return @result.instance_of?(klass) if @resolved

          _ensure_resolved!
          @result.instance_of?(klass)
        rescue ::FiberError
          false
        end

        def class = ToolFuture

        def hash
          return @result.hash if @resolved

          _ensure_resolved!
          @result.hash
        rescue ::FiberError
          __id__.hash
        end

        def eql?(other)
          return @result.eql?(other) if @resolved

          _ensure_resolved!
          @result.eql?(other)
        rescue ::FiberError
          false
        end

        def !
          return !@result if @resolved

          _ensure_resolved!
          !@result
        rescue ::FiberError
          true
        end

        def empty?
          return @result.empty? if @resolved

          _ensure_resolved!
          @result.empty?
        rescue ::FiberError
          false
        end
      end
    end
  end
end
