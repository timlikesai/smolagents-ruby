require "spec_helper"

RSpec.describe Smolagents::Executors::RactorLazy::Context do
  let(:tool_names) { %w[search calculate] }
  let(:tool_port) { double("tool_port") }
  let(:result_port) { double("result_port") }
  let(:initial_vars) { { "existing_var" => 42 } }
  let(:max_ops) { 1000 }

  describe ".build" do
    subject(:result) { described_class.build(tool_names:, tool_port:, result_port:, initial_vars:, max_ops:) }

    it "returns context, output, and batch" do
      ctx, output, batch = result
      expect(ctx).to be_a(Object)
      expect(output).to be_a(StringIO)
      expect(batch).to be_an(Array)
    end

    it "returns empty batch initially" do
      _, _, batch = result
      expect(batch).to be_empty
    end

    it "returns empty output initially" do
      _, output, _ = result
      expect(output.string).to eq("")
    end
  end

  describe "context methods" do
    let(:ctx) do
      ctx, _, _ = described_class.build(tool_names:, tool_port:, result_port:, initial_vars:, max_ops:)
      ctx
    end
    let(:output) do
      _, output, _ = described_class.build(tool_names:, tool_port:, result_port:, initial_vars:, max_ops:)
      output
    end

    describe "output helpers" do
      let(:result) { described_class.build(tool_names:, tool_port:, result_port:, initial_vars:, max_ops:) }
      let(:ctx) { result[0] }
      let(:output) { result[1] }

      describe "#puts" do
        it "writes to output with newline" do
          ctx.puts("hello")
          expect(output.string).to eq("hello\n")
        end
      end

      describe "#print" do
        it "writes to output without newline" do
          ctx.print("hello")
          expect(output.string).to eq("hello")
        end
      end

      describe "#p" do
        it "writes inspected value to output" do
          ctx.p("hello")
          expect(output.string).to eq("\"hello\"\n")
        end

        it "returns the first argument" do
          expect(ctx.p("hello")).to eq("hello")
        end
      end
    end

    describe "introspection" do
      describe "#tools" do
        it "lists tool names" do
          expect(ctx.tools).to include("search")
          expect(ctx.tools).to include("calculate")
        end
      end

      describe "#vars" do
        it "lists variable names" do
          expect(ctx.vars).to include("existing_var")
        end
      end

      describe "#help" do
        it "returns tools list without argument" do
          expect(ctx.help).to include("Tools:")
        end

        it "returns usage hint with argument" do
          expect(ctx.help(:search)).to include("Use: search")
        end
      end
    end

    describe "state management" do
      describe "#remember" do
        it "stores value in state" do
          ctx.remember(:my_var, "value")
          expect(ctx.my_var).to eq("value")
        end

        it "returns stored value" do
          expect(ctx.remember(:x, 42)).to eq(42)
        end

        it "creates accessor method" do
          ctx.remember(:new_var, "hello")
          expect(ctx).to respond_to(:new_var)
        end
      end
    end

    describe "variable access" do
      it "provides access to initial variables" do
        expect(ctx.existing_var).to eq(42)
      end

      it "handles method_missing for state keys" do
        ctx.remember(:dynamic, "value")
        expect(ctx.dynamic).to eq("value")
      end

      it "raises for truly missing methods" do
        expect { ctx.totally_unknown_method }.to raise_error(NoMethodError)
      end

      it "responds to state key methods" do
        expect(ctx.respond_to?(:existing_var)).to be true
      end

      it "does not respond to unknown methods" do
        expect(ctx.respond_to?(:unknown_method)).to be false
      end
    end

    describe "lazy tools" do
      it "defines method for each tool" do
        expect(ctx).to respond_to(:search)
        expect(ctx).to respond_to(:calculate)
      end

      it "returns ToolFuture when tool called" do
        future = ctx.search(query: "test")
        expect(future).to be_a(Smolagents::Executors::RactorLazy::ToolFuture)
      end

      it "passes arguments to ToolFuture" do
        future = ctx.calculate(a: 1, b: 2)
        expect(future.tool_name).to eq("calculate")
        expect(future.kwargs).to eq({ a: 1, b: 2 })
      end

      it "adds future to batch" do
        ctx, _, _ = described_class.build(tool_names:, tool_port:, result_port:, initial_vars:, max_ops:)
        # Get the batch from context
        batch_ref = ctx.instance_variable_get(:@batch)

        ctx.search(query: "test")
        expect(batch_ref.length).to eq(1)
      end
    end
  end

  describe ".setup_context" do
    it "sets up instance variables" do
      ctx = Object.new
      output = StringIO.new
      state = { foo: "bar" }
      batch = []

      described_class.setup_context(
        ctx,
        output:,
        state:,
        batch:,
        tool_port:,
        result_port:,
        max_ops:,
        tool_names:
      )

      expect(ctx.instance_variable_get(:@output)).to eq(output)
      expect(ctx.instance_variable_get(:@state)).to eq(state)
      expect(ctx.instance_variable_get(:@batch)).to eq(batch)
    end
  end

  describe ".setup_ivars" do
    it "sets instance variables on context" do
      ctx = Object.new
      described_class.setup_ivars(ctx, { foo: "bar", num: 42 })

      expect(ctx.instance_variable_get(:@foo)).to eq("bar")
      expect(ctx.instance_variable_get(:@num)).to eq(42)
    end
  end
end
