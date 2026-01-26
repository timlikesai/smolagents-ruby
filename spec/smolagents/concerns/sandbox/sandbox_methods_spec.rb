require "spec_helper"

RSpec.describe Smolagents::Concerns::SandboxMethods do
  let(:test_class) do
    Class.new do
      def initialize(output_buffer:, variables: {}, tools: {})
        @output_buffer = output_buffer
        @variables = variables
        @tools = tools
      end
    end
  end

  let(:output) { StringIO.new }
  let(:tools) { {} }
  let(:variables) { {} }
  let(:instance) { test_class.new(output_buffer: output, variables:, tools:) }

  before do
    described_class.define_on(test_class)
  end

  describe ".define_on" do
    it "defines output methods" do
      expect(instance).to respond_to(:puts)
      expect(instance).to respond_to(:print)
      expect(instance).to respond_to(:p)
    end

    it "defines help methods" do
      expect(instance).to respond_to(:tools)
      expect(instance).to respond_to(:help)
      expect(instance).to respond_to(:sandbox_help)
    end

    it "defines type check methods" do
      expect(instance).to respond_to(:is_a?)
      expect(instance).to respond_to(:kind_of?)
    end

    it "defines kernel delegates" do
      expect(instance).to respond_to(:raise)
      expect(instance).to respond_to(:loop)
    end
  end

  describe "output methods" do
    describe "#puts" do
      it "writes to output buffer with newline" do
        instance.puts("hello")
        expect(output.string).to eq("hello\n")
      end

      it "returns nil" do
        expect(instance.puts("test")).to be_nil
      end

      it "handles multiple arguments" do
        instance.puts("a", "b", "c")
        expect(output.string).to eq("a\nb\nc\n")
      end
    end

    describe "#print" do
      it "writes to output buffer without newline" do
        instance.print("hello")
        expect(output.string).to eq("hello")
      end

      it "returns nil" do
        expect(instance.print("test")).to be_nil
      end
    end

    describe "#p" do
      it "writes inspected value to output" do
        instance.p("hello")
        expect(output.string).to eq("\"hello\"\n")
      end

      it "returns the first argument" do
        expect(instance.p("hello")).to eq("hello")
      end

      it "returns array for multiple arguments" do
        expect(instance.p("a", "b")).to eq(%w[a b])
      end
    end

    describe "#rand" do
      it "returns random float without argument" do
        result = instance.rand
        expect(result).to be_a(Float)
        expect(result).to be >= 0
        expect(result).to be < 1
      end

      it "returns random integer with max" do
        result = instance.rand(10)
        expect(result).to be_a(Integer)
        expect(result).to be >= 0
        expect(result).to be < 10
      end
    end

    describe "#state" do
      let(:variables) { { "foo" => "bar" } }

      it "returns variables hash" do
        expect(instance.state).to eq(variables)
      end
    end
  end

  describe "help methods" do
    let(:mock_tool) do
      instance_double(Smolagents::Tools::Tool,
                      description: "Search the web. Returns results.",
                      help: "search(query: string)")
    end
    let(:tools) { { "search" => mock_tool } }

    describe "#tools" do
      it "lists available tools with descriptions" do
        result = instance.tools
        expect(result).to include("search")
        expect(result).to include("Search the web")
      end
    end

    describe "#help" do
      it "returns tool list without argument" do
        expect(instance.help).to include("search")
      end

      it "returns tool help with argument" do
        expect(instance.help(:search)).to eq("search(query: string)")
      end

      it "returns error for unknown tool" do
        expect(instance.help(:unknown)).to include("Unknown tool")
      end
    end

    describe "#sandbox_help" do
      it "returns sandbox reference text" do
        expect(instance.sandbox_help).to include("SANDBOX QUICK REFERENCE")
        expect(instance.sandbox_help).to include("puts(tools)")
      end
    end
  end

  describe "introspection methods" do
    describe "#vars" do
      it "returns message when no variables" do
        expect(instance.vars).to eq("No variables set")
      end

      it "lists variables with values" do
        variables["foo"] = "bar"
        variables["num"] = 42

        result = instance.vars
        expect(result).to include("foo = \"bar\"")
        expect(result).to include("num = 42")
      end
    end

    describe "#budget" do
      it "shows step budget" do
        variables["_step"] = 2
        variables["_max_steps"] = 10
        variables["_steps_remaining"] = 7

        expect(instance.budget).to eq("Step 3/10 (7 remaining)")
      end

      it "handles missing step info" do
        expect(instance.budget).to eq("Step 1/? (? remaining)")
      end
    end

    describe "#low_budget?" do
      it "returns false when no remaining info" do
        expect(instance).not_to be_low_budget
      end

      it "returns true when steps remaining < 3" do
        variables["_steps_remaining"] = 2
        expect(instance.low_budget?).to be true
      end

      it "returns false when steps remaining >= 3" do
        variables["_steps_remaining"] = 5
        expect(instance.low_budget?).to be false
      end
    end

    describe "#remember" do
      it "stores value in variables" do
        instance.remember(:foo, "bar")
        expect(variables["foo"]).to eq("bar")
      end

      it "returns the stored value" do
        expect(instance.remember(:foo, 42)).to eq(42)
      end

      it "tracks defined vars" do
        instance.remember(:first, 1)
        instance.remember(:second, 2)
        # Verify by remembering same var twice (shouldn't duplicate)
        instance.remember(:first, 10)

        # The defined_vars should only have unique entries
        defined = instance.instance_variable_get(:@defined_vars)
        expect(defined).to eq(%w[first second])
      end
    end
  end

  describe "type checks" do
    describe "#is_a? and #kind_of?" do
      it "always returns false for safety" do
        expect(instance.is_a?(String)).to be false
        expect(instance.is_a?(Object)).to be false
        # rubocop:disable Style/ClassCheck -- explicitly testing kind_of? method
        expect(instance.kind_of?(String)).to be false
        expect(instance.kind_of?(Object)).to be false
        # rubocop:enable Style/ClassCheck
      end
    end

    describe "#==" do
      it "uses object identity" do
        same = instance
        expect(instance == same).to be true
        expect(instance == test_class.new(output_buffer: output)).to be false
      end
    end

    describe "#!=" do
      it "uses object identity" do
        same = instance
        expect(instance != same).to be false
        expect(instance != test_class.new(output_buffer: output)).to be true
      end
    end
  end

  describe "kernel delegates" do
    describe "#raise" do
      it "raises exceptions" do
        expect { instance.raise("boom") }.to raise_error(RuntimeError, "boom")
      end

      it "raises specific error class" do
        expect { instance.raise(ArgumentError, "bad arg") }.to raise_error(ArgumentError, "bad arg")
      end
    end

    describe "#loop" do
      it "loops until break" do
        count = 0
        instance.loop do
          count += 1
          break if count >= 3
        end
        expect(count).to eq(3)
      end
    end
  end

  describe ".sandbox_fallback" do
    before { described_class.define_on(test_class) }

    it "returns false for nil?" do
      expect(test_class.sandbox_fallback(:nil?)).to be false
    end

    it "returns Object for class" do
      expect(test_class.sandbox_fallback(:class)).to eq(Object)
    end

    it "raises NoMethodError for unknown methods" do
      expect { test_class.sandbox_fallback(:unknown_method) }
        .to raise_error(NoMethodError, /undefined method.*sandbox/)
    end
  end
end
