module Smolagents
  module Concerns
    module ReActLoop
      module Control
        # Base module for control flow requests.
        #
        # Provides the common pattern for yielding control requests:
        # 1. Ensure fiber context
        # 2. Create typed request
        # 3. Yield and get response
        # 4. Extract result value
        #
        # @example Implementing a control request
        #   module MyRequest
        #     include RequestBase
        #
        #     def request_something(param:)
        #       yield_request(Types::ControlRequests::Something, param:, &:value)
        #     end
        #   end
        module RequestBase
          private

          # Yield a control request and extract the response.
          #
          # @param request_class [Class] The request type class
          # @param extractor [Proc, nil] How to extract result from response (default: &:value)
          # @param kwargs [Hash] Arguments for request creation
          # @yield [response] Optional block to extract result from response
          # @return [Object] Extracted result from response
          def yield_request(request_class, extractor: nil, **, &)
            ensure_fiber_context!
            request = request_class.create(**)
            response = yield_control(request)
            extract_response(response, extractor, &)
          end

          def extract_response(response, extractor, &block)
            return yield(response) if block
            return extractor.call(response) if extractor

            response.value
          end
        end
      end
    end
  end
end
