require "spec_helper"

RSpec.describe Smolagents::Executors::Executor::ToolRegistration do
  let(:registration_class) do
    Class.new do
      include Smolagents::Executors::Executor::ToolRegistration

      def initialize = initialize_tool_registration
    end
  end

  let(:registrar) { registration_class.new }
  let(:mock_tool) { instance_double(Smolagents::Tool) }

  describe "#send_tools" do
    it "registers tools with string keys" do
      registrar.send_tools({ "search" => mock_tool })

      expect(registrar.tools["search"]).to eq(mock_tool)
    end

    it "converts symbol keys to strings" do
      registrar.send_tools({ search: mock_tool })

      expect(registrar.tools["search"]).to eq(mock_tool)
    end

    it "registers multiple tools" do
      tool1 = instance_double(Smolagents::Tool)
      tool2 = instance_double(Smolagents::Tool)

      registrar.send_tools({ "search" => tool1, "web" => tool2 })

      expect(registrar.tools["search"]).to eq(tool1)
      expect(registrar.tools["web"]).to eq(tool2)
    end

    it "accumulates tools from multiple calls" do
      tool1 = instance_double(Smolagents::Tool)
      tool2 = instance_double(Smolagents::Tool)

      registrar.send_tools({ "search" => tool1 })
      registrar.send_tools({ "web" => tool2 })

      expect(registrar.tools.size).to eq(2)
    end

    it "overwrites existing tool with same name" do
      tool1 = instance_double(Smolagents::Tool)
      tool2 = instance_double(Smolagents::Tool)

      registrar.send_tools({ "search" => tool1 })
      registrar.send_tools({ "search" => tool2 })

      expect(registrar.tools["search"]).to eq(tool2)
    end

    context "with dangerous method names" do
      Smolagents::Security::Allowlists::DANGEROUS_METHODS.first(5).each do |dangerous_name|
        it "rejects tool named '#{dangerous_name}'" do
          expect do
            registrar.send_tools({ dangerous_name => mock_tool })
          end.to raise_error(ArgumentError, /dangerous name/)
        end
      end

      it "allows safe tool names" do
        expect do
          registrar.send_tools({ "safe_search" => mock_tool })
        end.not_to raise_error
      end
    end
  end

  describe "#send_variables" do
    it "registers variables with string keys" do
      registrar.send_variables({ "count" => 42 })

      expect(registrar.variables["count"]).to eq(42)
    end

    it "converts symbol keys to strings" do
      registrar.send_variables({ count: 42 })

      expect(registrar.variables["count"]).to eq(42)
    end

    it "registers multiple variables" do
      registrar.send_variables({ "x" => 1, "y" => 2, "z" => 3 })

      expect(registrar.variables["x"]).to eq(1)
      expect(registrar.variables["y"]).to eq(2)
      expect(registrar.variables["z"]).to eq(3)
    end

    it "handles various value types" do
      registrar.send_variables({
                                 "string" => "hello",
                                 "number" => 42,
                                 "array" => [1, 2, 3],
                                 "hash" => { a: 1 },
                                 "nil_val" => nil
                               })

      expect(registrar.variables["string"]).to eq("hello")
      expect(registrar.variables["number"]).to eq(42)
      expect(registrar.variables["array"]).to eq([1, 2, 3])
      expect(registrar.variables["hash"]).to eq({ a: 1 })
      expect(registrar.variables["nil_val"]).to be_nil
    end

    it "accumulates variables from multiple calls" do
      registrar.send_variables({ "a" => 1 })
      registrar.send_variables({ "b" => 2 })

      expect(registrar.variables.size).to eq(2)
    end

    it "overwrites existing variable with same name" do
      registrar.send_variables({ "x" => 1 })
      registrar.send_variables({ "x" => 100 })

      expect(registrar.variables["x"]).to eq(100)
    end
  end

  describe "accessor methods" do
    it "exposes tools via attr_reader" do
      expect(registrar.tools).to be_a(Hash)
    end

    it "exposes variables via attr_reader" do
      expect(registrar.variables).to be_a(Hash)
    end

    it "initializes tools to empty hash" do
      expect(registrar.tools).to eq({})
    end

    it "initializes variables to empty hash" do
      expect(registrar.variables).to eq({})
    end
  end
end
