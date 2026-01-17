require "spec_helper"

RSpec.describe Smolagents::Testing::BehaviorTracer, :slow do
  # Test class within Smolagents namespace for tracing
  before(:all) do
    module Smolagents
      class TestClass
        def greet(name)
          "Hello, #{name}!"
        end

        def calculate(first, second)
          first + second
        end

        def nested_call
          greet("nested")
        end
      end
    end
  end

  after(:all) do
    Smolagents.send(:remove_const, :TestClass)
  end

  let(:tracer) { described_class.new }
  let(:test_instance) { Smolagents::TestClass.new }

  describe "#trace" do
    it "returns a Trace object" do
      trace = tracer.trace { test_instance.greet("World") }
      expect(trace).to be_a(Smolagents::Testing::Trace)
    end

    it "captures the block result" do
      trace = tracer.trace { test_instance.greet("World") }
      expect(trace.result).to eq("Hello, World!")
    end

    it "records method calls" do
      trace = tracer.trace { test_instance.greet("World") }
      expect(trace.called?(:greet)).to be true
    end

    it "records multiple method calls" do
      trace = tracer.trace do
        test_instance.greet("Alice")
        test_instance.calculate(1, 2)
      end
      expect(trace.called?(:greet)).to be true
      expect(trace.called?(:calculate)).to be true
    end

    it "records nested calls" do
      trace = tracer.trace { test_instance.nested_call }
      expect(trace.called?(:nested_call)).to be true
      expect(trace.called?(:greet)).to be true
    end

    it "clears previous traces on each call" do
      tracer.trace { test_instance.greet("First") }
      trace = tracer.trace { test_instance.calculate(1, 2) }

      expect(trace.called?(:calculate)).to be true
      expect(trace.called?(:greet)).to be false
    end
  end

  describe "filter option" do
    it "filters by class name using regex" do
      filtered_tracer = described_class.new(filter: /TestClass/)
      trace = filtered_tracer.trace { test_instance.greet("World") }
      expect(trace.called?(:greet)).to be true
    end

    it "filters by class name using string" do
      filtered_tracer = described_class.new(filter: "TestClass")
      trace = filtered_tracer.trace { test_instance.greet("World") }
      expect(trace.called?(:greet)).to be true
    end

    it "excludes non-matching classes" do
      filtered_tracer = described_class.new(filter: /NonExistent/)
      trace = filtered_tracer.trace { test_instance.greet("World") }
      expect(trace.events).to be_empty
    end
  end
end

RSpec.describe Smolagents::Testing::TraceEvent do
  let(:call_event) do
    described_class.new(
      event_type: :call,
      method_name: :test_method,
      class_name: "Smolagents::TestClass",
      timestamp: 1000.0,
      path: "/path/to/file.rb",
      lineno: 42
    )
  end

  let(:return_event) do
    described_class.new(
      event_type: :return,
      method_name: :test_method,
      class_name: "Smolagents::TestClass",
      timestamp: 1001.0,
      path: "/path/to/file.rb",
      lineno: 42
    )
  end

  describe "#call?" do
    it "returns true for call events" do
      expect(call_event.call?).to be true
    end

    it "returns false for return events" do
      expect(return_event.call?).to be false
    end
  end

  describe "#return?" do
    it "returns true for return events" do
      expect(return_event.return?).to be true
    end

    it "returns false for call events" do
      expect(call_event.return?).to be false
    end
  end

  describe "#to_s" do
    it "formats call events" do
      expect(call_event.to_s).to eq("Smolagents::TestClass#test_method (call)")
    end

    it "formats return events" do
      expect(return_event.to_s).to eq("Smolagents::TestClass#test_method (return)")
    end
  end
end

RSpec.describe Smolagents::Testing::Trace do
  let(:events) do
    [
      Smolagents::Testing::TraceEvent.new(
        event_type: :call, method_name: :first_method, class_name: "Test", timestamp: 1000.0, path: "a.rb", lineno: 1
      ),
      Smolagents::Testing::TraceEvent.new(
        event_type: :return, method_name: :first_method, class_name: "Test", timestamp: 1001.0, path: "a.rb", lineno: 1
      ),
      Smolagents::Testing::TraceEvent.new(
        event_type: :call, method_name: :second_method, class_name: "Test", timestamp: 1002.0, path: "a.rb", lineno: 5
      ),
      Smolagents::Testing::TraceEvent.new(
        event_type: :call, method_name: :second_method, class_name: "Test", timestamp: 1003.0, path: "a.rb", lineno: 5
      ),
      Smolagents::Testing::TraceEvent.new(
        event_type: :return, method_name: :second_method, class_name: "Test", timestamp: 1004.0, path: "a.rb", lineno: 5
      ),
      Smolagents::Testing::TraceEvent.new(
        event_type: :return, method_name: :second_method, class_name: "Test", timestamp: 1005.0, path: "a.rb", lineno: 5
      )
    ]
  end

  let(:trace) { described_class.new(events:, result: "test result") }
  let(:empty_trace) { described_class.new(events: [], result: nil) }

  describe "#called?" do
    it "returns true for called methods" do
      expect(trace.called?(:first_method)).to be true
      expect(trace.called?(:second_method)).to be true
    end

    it "returns false for non-called methods" do
      expect(trace.called?(:unknown_method)).to be false
    end

    it "returns false for empty trace" do
      expect(empty_trace.called?(:any_method)).to be false
    end
  end

  describe "#call_count" do
    it "counts single calls" do
      expect(trace.call_count(:first_method)).to eq(1)
    end

    it "counts multiple calls" do
      expect(trace.call_count(:second_method)).to eq(2)
    end

    it "returns zero for non-called methods" do
      expect(trace.call_count(:unknown_method)).to eq(0)
    end
  end

  describe "#call_order" do
    it "returns unique methods in order" do
      expect(trace.call_order).to eq(%i[first_method second_method])
    end

    it "returns empty array for empty trace" do
      expect(empty_trace.call_order).to eq([])
    end
  end

  describe "#calls_to" do
    it "returns all call events for a method" do
      calls = trace.calls_to(:second_method)
      expect(calls.size).to eq(2)
      expect(calls).to all(be_a(Smolagents::Testing::TraceEvent))
      expect(calls).to all(have_attributes(method_name: :second_method, call?: true))
    end

    it "returns empty array for non-called methods" do
      expect(trace.calls_to(:unknown_method)).to eq([])
    end
  end

  describe "#called_in_order?" do
    it "returns true when methods were called in order" do
      expect(trace.called_in_order?(:first_method, :second_method)).to be true
    end

    it "returns false when methods were not called in order" do
      expect(trace.called_in_order?(:second_method, :first_method)).to be false
    end

    it "returns true for single method" do
      expect(trace.called_in_order?(:first_method)).to be true
    end

    it "returns true for empty method list" do
      expect(trace.called_in_order?).to be true
    end

    it "handles missing methods" do
      expect(trace.called_in_order?(:first_method, :unknown_method)).to be false
    end
  end

  describe "#call_sequence" do
    it "returns formatted call strings" do
      sequence = trace.call_sequence
      expect(sequence).to eq([
                               "Test#first_method (call)",
                               "Test#second_method (call)",
                               "Test#second_method (call)"
                             ])
    end

    it "returns empty array for empty trace" do
      expect(empty_trace.call_sequence).to eq([])
    end
  end

  describe "#duration" do
    it "calculates duration from first to last event" do
      expect(trace.duration).to eq(5.0)
    end

    it "returns zero for empty trace" do
      expect(empty_trace.duration).to eq(0)
    end
  end

  describe "#result" do
    it "returns the captured result" do
      expect(trace.result).to eq("test result")
    end
  end
end
