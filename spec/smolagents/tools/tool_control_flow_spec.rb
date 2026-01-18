RSpec.describe "Tool Control Flow", type: :feature do
  let(:tool_class) do
    Class.new(Smolagents::Tool) do
      self.tool_name = "control_flow_test"
      self.description = "Tool for testing control flow"
      self.inputs = { value: { type: "string", description: "Input value" } }
      self.output_type = "string"

      attr_accessor :input_response, :confirmation_response

      def execute(value:)
        answer = request_input("Choose format:", options: %w[json yaml], default_value: "json")
        "Formatted #{value} as #{answer}"
      end
    end
  end

  let(:tool) { tool_class.new }

  def with_fiber_context
    # Use thread_variable_set for true thread-local storage (not fiber-local)
    Thread.current.thread_variable_set(Smolagents::Tools::Tool::Execution::FIBER_CONTEXT_KEY, true)
    yield
  ensure
    Thread.current.thread_variable_set(Smolagents::Tools::Tool::Execution::FIBER_CONTEXT_KEY, nil)
  end

  describe "#request_input" do
    context "when outside fiber context" do
      it "returns default_value immediately" do
        result = tool.request_input("Choose:", default_value: "default")
        expect(result).to eq("default")
      end

      it "returns nil when no default_value" do
        result = tool.request_input("Choose:")
        expect(result).to be_nil
      end
    end

    context "when inside fiber context" do
      it "yields UserInput request and returns response value" do
        fiber = Fiber.new do
          with_fiber_context do
            tool.request_input("Pick one:", options: %w[a b], default_value: "a")
          end
        end

        request_received = fiber.resume
        expect(request_received).to be_a(Smolagents::Types::ControlRequests::UserInput)
        expect(request_received.prompt).to eq("Pick one:")
        expect(request_received.options).to eq(%w[a b])
        expect(request_received.default_value).to eq("a")

        response = Smolagents::Types::ControlRequests::Response.respond(
          request_id: request_received.id,
          value: "b"
        )
        response_value = fiber.resume(response)

        expect(response_value).to eq("b")
      end

      it "returns default_value when response value is nil" do
        fiber = Fiber.new do
          with_fiber_context do
            tool.request_input("Pick:", default_value: "fallback")
          end
        end

        request = fiber.resume
        response = Smolagents::Types::ControlRequests::Response.respond(
          request_id: request.id,
          value: nil
        )
        result = fiber.resume(response)

        expect(result).to eq("fallback")
      end
    end
  end

  describe "#request_confirmation" do
    context "when outside fiber context" do
      it "returns true for reversible actions" do
        result = tool.request_confirmation(
          action: "update",
          description: "Update config",
          reversible: true
        )
        expect(result).to be true
      end

      it "returns false for irreversible actions" do
        result = tool.request_confirmation(
          action: "delete",
          description: "Delete file",
          reversible: false
        )
        expect(result).to be false
      end
    end

    context "when inside fiber context" do
      it "yields Confirmation request and returns approval status" do
        fiber = Fiber.new do
          with_fiber_context do
            tool.request_confirmation(
              action: "delete",
              description: "Delete config.yml",
              consequences: ["Data will be lost"],
              reversible: false
            )
          end
        end

        request = fiber.resume
        expect(request).to be_a(Smolagents::Types::ControlRequests::Confirmation)
        expect(request.action).to eq("delete")
        expect(request.description).to eq("Delete config.yml")
        expect(request.consequences).to eq(["Data will be lost"])
        expect(request.reversible).to be false

        response = Smolagents::Types::ControlRequests::Response.approve(request_id: request.id)
        result = fiber.resume(response)

        expect(result).to be true
      end

      it "returns false when denied" do
        fiber = Fiber.new do
          with_fiber_context do
            tool.request_confirmation(action: "delete", description: "Delete file")
          end
        end

        request = fiber.resume
        response = Smolagents::Types::ControlRequests::Response.deny(
          request_id: request.id,
          reason: "User declined"
        )
        result = fiber.resume(response)

        expect(result).to be false
      end

      it "returns false when response is nil" do
        fiber = Fiber.new do
          with_fiber_context do
            tool.request_confirmation(action: "delete", description: "Delete file")
          end
        end

        fiber.resume
        result = fiber.resume(nil)

        expect(result).to be false
      end
    end
  end

  describe "integration with tool execution" do
    let(:interactive_tool_class) do
      Class.new(Smolagents::Tool) do
        self.tool_name = "interactive_tool"
        self.description = "Tool that interacts with user"
        self.inputs = { filename: { type: "string", description: "File to process" } }
        self.output_type = "string"

        def execute(filename:)
          format = request_input("Output format?", options: %w[json yaml], default_value: "json")

          if request_confirmation(action: "write", description: "Write to #{filename}")
            "Wrote #{filename} as #{format}"
          else
            "Cancelled"
          end
        end
      end
    end

    let(:interactive_tool) { interactive_tool_class.new }

    it "handles multiple control flow requests in sequence" do
      fiber = Fiber.new do
        with_fiber_context do
          interactive_tool.call(filename: "config.yml", wrap_result: false)
        end
      end

      # First request: input
      input_request = fiber.resume
      expect(input_request).to be_a(Smolagents::Types::ControlRequests::UserInput)
      expect(input_request.prompt).to eq("Output format?")

      # Respond with yaml
      input_response = Smolagents::Types::ControlRequests::Response.respond(
        request_id: input_request.id,
        value: "yaml"
      )

      # Second request: confirmation
      confirm_request = fiber.resume(input_response)
      expect(confirm_request).to be_a(Smolagents::Types::ControlRequests::Confirmation)
      expect(confirm_request.action).to eq("write")

      # Approve
      confirm_response = Smolagents::Types::ControlRequests::Response.approve(
        request_id: confirm_request.id
      )

      # Final result
      result = fiber.resume(confirm_response)
      expect(result).to eq("Wrote config.yml as yaml")
    end

    it "uses defaults and auto-approval when outside fiber context" do
      result = interactive_tool.call(filename: "test.yml", wrap_result: false)
      expect(result).to eq("Wrote test.yml as json")
    end
  end
end
