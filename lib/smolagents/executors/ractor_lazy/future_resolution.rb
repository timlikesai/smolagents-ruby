module Smolagents
  module Executors
    module RactorLazy
      # Future resolution helpers for FiberExecutor.
      #
      # Handles detecting, resolving, and unwrapping ToolFuture values
      # including nested futures in collections.
      module FutureResolution
        def tool_future?(value)
          begin
            value.respond_to?(:_future?)
          rescue StandardError
            false
          end && value._future?
        end

        def resolve_all_pending(value)
          return if value.nil?

          if tool_future?(value)
            force_resolve unless value._resolved?
            return
          end

          resolve_pending_collection(value)
        end

        def resolve_pending_collection(value)
          case value
          when Array then value.each { |v| resolve_all_pending(v) }
          when Hash then value.each_value { |v| resolve_all_pending(v) }
          end
        end

        def unwrap_future(value)
          return value if value.nil?
          return unwrap_tool_future(value) if tool_future?(value)

          unwrap_collection(value)
        end

        def unwrap_tool_future(future)
          err = future._error
          ::Kernel.raise err if err
          future._resolved? ? future._result : future.inspect
        end

        def unwrap_collection(value)
          case value
          when Array then value.map { |v| unwrap_future(v) }
          when Hash then value.transform_values { |v| unwrap_future(v) }
          else value
          end
        end
      end
    end
  end
end
