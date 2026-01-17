module Smolagents
  module Concerns
    module ReActLoop
      # Bidirectional Fiber control flow for user input, confirmation, and escalation.
      #
      # This concern enables agents to pause execution and request external input.
      # It requires Fiber-based execution via {Core#run_fiber} to function.
      #
      # == Control Flow Pattern
      #
      # When an agent needs external input, it:
      # 1. Creates a control request (UserInput, Confirmation, or SubAgentQuery)
      # 2. Yields the request via Fiber.yield
      # 3. Receives a Response when the Fiber is resumed
      # 4. Continues execution with the response value
      #
      # == Events Emitted
      #
      # - {Events::ControlYielded} - When control is yielded
      # - {Events::ControlResumed} - When control returns
      #
      # == Sync Mode Behavior
      #
      # When using {Core#run} (sync mode), control requests are auto-handled
      # based on their sync_behavior setting:
      # - :approve - Auto-approve confirmations
      # - :default - Use default_value if available
      # - :skip - Skip with nil value
      #
      # @example Requesting user input
      #   # Inside agent code:
      #   def step(task, step_number:)
      #     # ... determine we need user clarification
      #     clarification = request_input("What specific aspect interests you?")
      #     # ... use clarification to continue
      #   end
      #
      # @example Handling control requests externally
      #   fiber = agent.run_fiber("task")
      #   loop do
      #     case fiber.resume
      #     in Types::ControlRequests::UserInput => req
      #       answer = gets.chomp
      #       fiber.resume(Types::ControlRequests::Response.respond(request_id: req.id, value: answer))
      #     in Types::RunResult => result
      #       break result
      #     end
      #   end
      #
      # @see Core#run_fiber For Fiber-based execution
      # @see Types::ControlRequests For request/response types
      module Control
        # Request input from an external source.
        #
        # Pauses agent execution and yields a {Types::ControlRequests::UserInput}
        # request. The Fiber must be resumed with a Response containing the input.
        #
        # @param prompt [String] Question or prompt for the user
        # @param options [Array<String>, nil] Valid response options (if constrained)
        # @param timeout [Integer, nil] Timeout in seconds (informational)
        # @param context [Hash] Additional context for the request handler
        # @return [String, Object] The value from the Response
        # @raise [Errors::ControlFlowError] If not in Fiber context
        def request_input(prompt, options: nil, timeout: nil, context: {})
          ensure_fiber_context!
          response = yield_control(Types::ControlRequests::UserInput.create(prompt:, options:, timeout:, context:))
          response.value
        end

        # Request confirmation for an action.
        #
        # Pauses execution and yields a {Types::ControlRequests::Confirmation}
        # request. Returns true if approved, false otherwise.
        #
        # @param action [String] Short action name (e.g., "delete_file")
        # @param description [String] Human-readable description of the action
        # @param consequences [Array<String>] List of potential consequences
        # @param reversible [Boolean] Whether the action can be undone
        # @return [Boolean] True if approved, false if denied
        # @raise [Errors::ControlFlowError] If not in Fiber context
        def request_confirmation(action:, description:, consequences: [], reversible: true) # rubocop:disable Naming/PredicateMethod
          ensure_fiber_context!
          request = Types::ControlRequests::Confirmation.create(action:, description:, consequences:, reversible:)
          yield_control(request).approved?
        end

        # Escalate a query to another agent or external handler.
        #
        # Used for delegation patterns where one agent needs to consult
        # another agent or expert system.
        #
        # @param query [String] The query to escalate
        # @param options [Hash, nil] Additional options for the handler
        # @param context [Hash] Context about the escalation
        # @return [String, Object] Response from the handler
        # @raise [Errors::ControlFlowError] If not in Fiber context
        def escalate_query(query, options: nil, context: {})
          ensure_fiber_context!
          request = Types::ControlRequests::SubAgentQuery.create(agent_name: agent_name_for_escalation,
                                                                 query:, options:, context:)
          yield_control(request).value
        end

        private

        def consume_fiber(fiber)
          loop do
            case fiber.resume
            in Types::ActionStep then next
            in Types::ControlRequests::Request => req then fiber.resume(handle_sync_control_request(req))
            in Types::RunResult => final then return final
            end
          end
        end

        def handle_sync_control_request(req)
          case req.sync_behavior
          in :default then sync_default_response(req)
          in :approve then Types::ControlRequests::Response.approve(request_id: req.id)
          in :skip then Types::ControlRequests::Response.respond(request_id: req.id, value: nil)
          else raise_sync_error(req)
          end
        end

        def sync_default_response(req)
          value = req.respond_to?(:default_value) ? req.default_value : nil
          value ? Types::ControlRequests::Response.respond(request_id: req.id, value:) : raise_sync_error(req)
        end

        def raise_sync_error(req)
          raise ControlFlowError.new("Control request #{req.class.name} cannot be handled in sync mode",
                                     request_type: req.class.name.split("::").last.to_sym, context: req.to_h)
        end

        def yield_control(request)
          emit(Events::ControlYielded.create(request_type: request_type_sym(request), request_id: request.id,
                                             prompt: extract_prompt(request)))
          response = Fiber.yield(request)
          emit(Events::ControlResumed.create(request_id: request.id, approved: response.approved?,
                                             value: response.value&.to_s&.slice(0, 100)))
          response
        end

        def request_type_sym(req) = req.class.name.split("::").last.downcase.to_sym

        def extract_prompt(req)
          %i[prompt query description].find { |m| req.respond_to?(m) }&.then { |m| req.send(m) } || req.to_h.to_s
        end

        def ensure_fiber_context!
          return if fiber_context?

          raise Errors::ControlFlowError, "Control requests require Fiber context. Use run_fiber instead of run."
        end

        def agent_name_for_escalation
          class_name = self.class.name
          class_name ? class_name.split("::").last.downcase : "agent"
        end
      end
    end
  end
end
