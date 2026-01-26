require "spec_helper"

# Edge case tests for outer ToolFuture (Executors::ToolFuture)
#
# Covers scenarios not fully tested in tool_future_spec.rb:
# - Auto-resolution triggering via method access
# - Error propagation through _ensure_resolved!
# - Complex FutureBatch interactions
# - Thread safety of batch operations
RSpec.describe Smolagents::Executors::ToolFuture do
  before { Smolagents::Executors::FutureBatch.clear! }
  after { Smolagents::Executors::FutureBatch.clear! }

  let(:executor) { -> { "executed result" } }

  def create_future(name = "test", arguments: {}, exec: executor)
    described_class.new(tool_name: name, arguments:, executor: exec)
  end

  describe "auto-resolution on method access" do
    context "outside Fiber context" do
      it "triggers synchronous execution on method call" do
        executed = false
        exec = lambda {
          executed = true
          "result"
        }
        future = create_future(exec:)

        expect(executed).to be false

        # Any method access triggers resolution
        _ = future.upcase

        expect(executed).to be true
      end

      it "triggers resolution on to_s" do
        future = create_future
        expect(future._resolved?).to be false

        _ = future.to_s

        expect(future._resolved?).to be true
      end

      it "triggers resolution on ==" do
        future = create_future
        expect(future._resolved?).to be false

        _ = future == "something"

        expect(future._resolved?).to be true
      end

      it "triggers resolution on []" do
        exec = -> { { key: "value" } }
        future = create_future(exec:)

        result = future[:key]

        expect(result).to eq("value")
        expect(future._resolved?).to be true
      end

      it "triggers resolution on each" do
        exec = -> { [1, 2, 3] }
        future = create_future(exec:)

        collected = future.map { |x| x }

        expect(collected).to eq([1, 2, 3])
        expect(future._resolved?).to be true
      end
    end

    context "inside Fiber context" do
      it "yields BatchYield for orchestrator handling" do
        yielded = nil
        fiber = Fiber.new do
          Thread.current[:smolagents_in_code_fiber] = true
          begin
            Smolagents::Executors::FutureBatch.clear!
            future = create_future
            future.to_s # Trigger resolution
          ensure
            Thread.current[:smolagents_in_code_fiber] = false
          end
        end

        result = fiber.resume
        yielded = result if result.is_a?(Smolagents::Executors::BatchYield)

        expect(yielded).to be_a(Smolagents::Executors::BatchYield)
        expect(yielded.size).to eq(1)
      end
    end
  end

  describe "error propagation through _execute!" do
    it "stores error after execution failure" do
      exec = -> { raise StandardError, "tool failure" }
      future = create_future(exec:)

      expect { future._execute! }.to raise_error(StandardError, "tool failure")

      expect(future._resolved?).to be true
      expect(future._error).to be_a(StandardError)
      expect(future._error.message).to eq("tool failure")
    end

    it "marks future as resolved even after error" do
      exec = -> { raise ArgumentError, "bad args" }
      future = create_future(exec:)

      begin
        future._execute!
      rescue ArgumentError
        # Expected
      end

      expect(future._resolved?).to be true
      expect(future._error).to be_a(ArgumentError)
    end

    it "stores error from _reject!" do
      future = create_future
      error = RuntimeError.new("injected error")
      future._reject!(error)

      expect(future._resolved?).to be true
      expect(future._error).to eq(error)
    end
  end

  describe "FutureBatch edge cases" do
    describe "batch with mixed resolution states" do
      it "only resolves pending futures" do
        call_counts = Hash.new(0)

        f1 = create_future("already_resolved", exec: lambda {
          call_counts["f1"] += 1
          "r1"
        })
        f1._resolve!("pre-resolved")

        create_future("pending", exec: lambda {
          call_counts["f2"] += 1
          "r2"
        })

        Smolagents::Executors::FutureBatch.resolve_all!

        expect(call_counts["f1"]).to eq(0) # Was already resolved
        expect(call_counts["f2"]).to eq(1)
      end
    end

    describe "batch error handling" do
      it "continues resolving other futures after one fails" do
        results = []

        f1 = create_future("good1", exec: lambda {
          results << "f1"
          "result1"
        })

        f2 = create_future("bad", exec: lambda {
          results << "f2"
          raise StandardError, "f2 failed"
        })

        f3 = create_future("good2", exec: lambda {
          results << "f3"
          "result3"
        })

        # Execute all (f2 will raise)
        expect { f2._execute! }.to raise_error(StandardError)
        f1._execute!
        f3._execute!

        expect(results).to contain_exactly("f1", "f2", "f3")
        expect(f1._resolved?).to be true
        expect(f2._resolved?).to be true
        expect(f3._resolved?).to be true
      end
    end

    describe "thread isolation" do
      it "maintains separate batches per thread" do
        main_future = create_future("main")

        thread_batch = Thread.new do
          Smolagents::Executors::FutureBatch.clear!
          create_future("thread")
          Smolagents::Executors::FutureBatch.current.dup
        end.value

        # Main thread batch contains main_future
        expect(Smolagents::Executors::FutureBatch.current).to include(main_future)
        # Thread batch is separate and contains only thread future
        expect(thread_batch.size).to eq(1)
        expect(thread_batch.first.tool_name).to eq("thread")
        # The thread's future is NOT in main thread's batch
        expect(Smolagents::Executors::FutureBatch.current.map(&:tool_name)).not_to include("thread")
      end

      it "allows concurrent batch operations" do
        threads = Array.new(3) do |i|
          Thread.new do
            Smolagents::Executors::FutureBatch.clear!
            f = described_class.new(
              tool_name: "thread_#{i}",
              arguments: {},
              executor: lambda {
                # rubocop:disable Smolagents/NoSleep -- intentional delay to test thread interleaving
                sleep 0.01
                # rubocop:enable Smolagents/NoSleep
                "result_#{i}"
              }
            )
            Smolagents::Executors::FutureBatch.resolve_all!
            f._result
          end
        end

        thread_results = threads.map(&:value)
        expect(thread_results).to contain_exactly("result_0", "result_1", "result_2")
      end
    end

    describe "clear! during resolution" do
      it "handles clear! between registrations" do
        create_future("first")
        Smolagents::Executors::FutureBatch.clear!
        create_future("second")

        # After clear, only f2 is in the batch
        current_batch = Smolagents::Executors::FutureBatch.current
        expect(current_batch.size).to eq(1)
        expect(current_batch.first.tool_name).to eq("second")
        # f1 is not in the batch (comparison by tool_name to avoid resolution)
        expect(current_batch.map(&:tool_name)).not_to include("first")
      end
    end
  end

  describe "resolve ordering" do
    it "executes futures in registration order" do
      execution_order = []

      create_future("first", exec: lambda {
        execution_order << 1
        "r1"
      })

      create_future("second", exec: lambda {
        execution_order << 2
        "r2"
      })

      create_future("third", exec: lambda {
        execution_order << 3
        "r3"
      })

      Smolagents::Executors::FutureBatch.resolve_all!

      expect(execution_order).to eq([1, 2, 3])
    end
  end

  describe "result type preservation" do
    it "preserves nil result" do
      exec = -> {}
      future = create_future(exec:)
      future._execute!

      expect(future._result).to be_nil
      expect(future._resolved?).to be true
    end

    it "preserves false result" do
      exec = -> { false }
      future = create_future(exec:)
      future._execute!

      expect(future._result).to be false
      expect(future._resolved?).to be true
    end

    it "preserves complex nested structures" do
      exec = -> { { data: [1, { nested: true }], count: 5 } }
      future = create_future(exec:)
      future._execute!

      expect(future._result).to eq({ data: [1, { nested: true }], count: 5 })
    end
  end

  describe "_ensure_resolved! edge cases" do
    it "raises specific error message when batch fails to resolve" do
      # Create a scenario where future isn't resolved after batch
      # This shouldn't happen in practice but tests the guard clause
      future = create_future

      # Mock FutureBatch to not actually resolve
      allow(Smolagents::Executors::FutureBatch).to receive(:resolve_all!)

      expect do
        future.send(:_ensure_resolved!)
      end.to raise_error(RuntimeError, /not resolved after batch/)
    end
  end
end
