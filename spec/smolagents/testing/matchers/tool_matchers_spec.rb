require "spec_helper"

RSpec.describe Smolagents::Testing::Matchers::ToolMatchers do
  describe ".included" do
    it "registers matchers when RSpec is defined" do
      test_module = Module.new
      test_module.include(described_class)
      expect(test_module).to include(described_class)
    end
  end

  describe "call_tool matcher" do
    describe "with SpyTool" do
      let(:spy) { Smolagents::Testing::SpyTool.new("search") }

      it "passes when tool was called" do
        spy.execute(query: "Ruby")
        expect(spy).to call_tool("search")
      end

      it "passes with matching arguments" do
        spy.execute(query: "Ruby", limit: 10)
        expect(spy).to call_tool("search").with_arguments(query: "Ruby")
      end

      it "passes with multiple matching arguments" do
        spy.execute(query: "Ruby", limit: 10)
        expect(spy).to call_tool("search").with_arguments(query: "Ruby", limit: 10)
      end

      it "fails when arguments do not match" do
        spy.execute(query: "Python")

        expect do
          expect(spy).to call_tool("search").with_arguments(query: "Ruby")
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected tool call to search.*Ruby.*Python/m)
      end

      it "fails when tool was not called" do
        expect do
          expect(spy).to call_tool("search").with_arguments(query: "Ruby")
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected tool call to search/)
      end
    end

    describe "with raw call array" do
      it "passes when call found in array" do
        calls = [{ query: "Ruby" }, { query: "Python" }]
        expect(calls).to call_tool("search")
      end

      it "passes with matching arguments" do
        calls = [{ query: "Ruby", limit: 10 }]
        expect(calls).to call_tool("search").with_arguments(query: "Ruby")
      end

      it "supports string keys" do
        calls = [{ "query" => "Ruby" }]
        expect(calls).to call_tool("search").with_arguments(query: "Ruby")
      end

      it "fails on empty array" do
        expect do
          expect([]).to call_tool("search").with_arguments(query: "Ruby")
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected tool call to search/)
      end
    end

    describe "multiple calls" do
      let(:spy) { Smolagents::Testing::SpyTool.new("search") }

      it "passes when any call matches" do
        spy.execute(query: "first")
        spy.execute(query: "Ruby")
        spy.execute(query: "last")

        expect(spy).to call_tool("search").with_arguments(query: "Ruby")
      end

      it "verifies call_count alongside matcher" do
        spy.execute(query: "one")
        spy.execute(query: "two")

        expect(spy.call_count).to eq(2)
        expect(spy).to call_tool("search").with_arguments(query: "one")
        expect(spy).to call_tool("search").with_arguments(query: "two")
      end
    end
  end
end
