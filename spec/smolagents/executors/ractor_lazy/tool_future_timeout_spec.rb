require "spec_helper"

# Timeout and cancellation edge case tests for RactorLazy::ToolFuture
#
# Covers scenarios not fully tested in tool_future_spec.rb:
# - Timeout interaction with batch resolution
# - Multiple futures with different timeouts
# - Cancellation followed by batch attempts
# - Timeout checking at various stages
RSpec.describe Smolagents::Executors::RactorLazy::ToolFuture do
  let(:batch) { [] }

  def create_future(name, args: [], kwargs: {}) = described_class.new(name, args, kwargs, batch)

  describe "timeout edge cases" do
    describe "pre-resolution timeout check" do
      it "times out before batch resolution can happen" do
        future = create_future("slow")
        future._with_timeout(0.001)

        # Simulate time passing
        initial_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        allow(Process).to receive(:clock_gettime)
          .with(Process::CLOCK_MONOTONIC)
          .and_return(initial_time + 1)

        fiber = Fiber.new { future.to_s }
        expect { fiber.resume }.to raise_error(/timed out after/)

        # Future should be marked as resolved with error
        expect(future._resolved?).to be true
        expect(future._error).to include("timed out")
      end

      it "checks timeout after batch resolution" do
        future = create_future("test")
        future._with_timeout(0.5)

        # Resolve the future (simulating successful batch)
        future._resolve!("result")

        # Now access should succeed even with timeout set
        expect(future._resolved?).to be true
        expect(future._result).to eq("result")
      end
    end

    describe "multiple futures with different timeouts" do
      it "each future tracks its own timeout independently" do
        f1 = create_future("fast")._with_timeout(1.0)
        f2 = create_future("slow")._with_timeout(10.0)

        expect(f1._timeout).to eq(1.0)
        expect(f2._timeout).to eq(10.0)
        expect(f1._timeout_at).to be < f2._timeout_at
      end

      it "timed_out? works independently for each future" do
        f1 = create_future("short")._with_timeout(0.001)
        f2 = create_future("long")._with_timeout(60)

        # Simulate time advancing past short timeout but not long
        initial_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        allow(Process).to receive(:clock_gettime)
          .with(Process::CLOCK_MONOTONIC)
          .and_return(initial_time + 1)

        expect(f1._timed_out?).to be true
        expect(f2._timed_out?).to be false
      end
    end

    describe "timeout without _with_timeout" do
      it "never times out without explicit timeout" do
        future = create_future("no_timeout")

        expect(future._timeout).to be_nil
        expect(future._timeout_at).to be_nil
        # _timed_out? returns nil (falsy) when no timeout is set
        expect(future).not_to be__timed_out
      end
    end
  end

  describe "cancellation edge cases" do
    describe "cancel then batch attempt" do
      it "raises immediately when accessing cancelled future" do
        future = create_future("cancelled")
        future._cancel!("User cancelled")

        fiber = Fiber.new { future.to_s }
        expect { fiber.resume }.to raise_error("User cancelled")
      end

      it "cancelled future does not participate in batch" do
        f1 = create_future("cancelled")
        f2 = create_future("pending")

        f1._cancel!("Cancelled")

        # Only f2 should be pending
        pending = batch.select(&:_pending?)
        expect(pending).to eq([f2])
      end
    end

    describe "resolve after cancel attempt" do
      it "stays cancelled even if resolve is called after cancel" do
        future = create_future("test")
        future._cancel!("Cancelled first")
        future._resolve!("Too late")

        # Cancellation state is preserved
        expect(future._cancelled?).to be true
        expect(future._error).to eq("Cancelled first")
        # NOTE: FutureBase._resolve! overwrites @result, but cancellation is still honored
        # because @cancelled is checked first in _ensure_resolved!
        # The result is stored but not accessible due to cancellation
      end
    end

    describe "cancel with custom reason" do
      it "uses custom cancellation reason" do
        future = create_future("test")
        future._cancel!("API rate limit exceeded")

        fiber = Fiber.new { future.first }
        expect { fiber.resume }.to raise_error("API rate limit exceeded")
      end
    end
  end

  describe "error vs cancellation semantics" do
    it "distinguishes rejection from cancellation" do
      rejected = create_future("rejected")
      cancelled = create_future("cancelled")

      rejected._reject!("Tool error")
      cancelled._cancel!("User cancel")

      expect(rejected._cancelled?).to be false
      expect(cancelled._cancelled?).to be true

      # Both are resolved
      expect(rejected._resolved?).to be true
      expect(cancelled._resolved?).to be true

      # Both have errors
      expect(rejected._error).to eq("Tool error")
      expect(cancelled._error).to eq("User cancel")
    end
  end

  describe "state combinations" do
    it "pending future: not resolved, not cancelled, not timed out" do
      future = create_future("pending")

      expect(future._pending?).to be true
      expect(future._resolved?).to be false
      expect(future._cancelled?).to be false
      expect(future).not_to be__timed_out # Returns nil when no timeout set
    end

    it "resolved future: resolved, not cancelled" do
      future = create_future("resolved")
      future._resolve!("done")

      expect(future._pending?).to be false
      expect(future._resolved?).to be true
      expect(future._cancelled?).to be false
      expect(future._result).to eq("done")
    end

    it "rejected future: resolved, not cancelled, has error" do
      future = create_future("rejected")
      future._reject!("error")

      expect(future._pending?).to be false
      expect(future._resolved?).to be true
      expect(future._cancelled?).to be false
      expect(future._error).to eq("error")
    end

    it "cancelled future: resolved, cancelled, has error" do
      future = create_future("cancelled")
      future._cancel!

      expect(future._pending?).to be false
      expect(future._resolved?).to be true
      expect(future._cancelled?).to be true
      expect(future._error).to eq("Cancelled")
    end

    it "timed out future: resolved with timeout error" do
      future = create_future("timeout")
      future._with_timeout(0.001)

      # Simulate timeout
      initial_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      allow(Process).to receive(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC)
        .and_return(initial_time + 1)

      fiber = Fiber.new { future.first }
      expect { fiber.resume }.to raise_error(/timed out/)

      expect(future._resolved?).to be true
      expect(future._error).to include("timed out")
    end
  end

  describe "_with_timeout chaining" do
    it "returns self for method chaining" do
      future = create_future("test")

      result = future._with_timeout(5)

      expect(result).to equal(future)
    end

    it "allows chaining with other operations" do
      future = create_future("test")._with_timeout(5)
      future._resolve!("done")

      expect(future._result).to eq("done")
    end
  end

  describe "inspect with timeout and cancellation" do
    it "shows cancelled state" do
      future = create_future("search")
      future._cancel!

      expect(future.inspect).to eq("#<Future:cancelled search>")
    end

    it "shows pending state even with timeout set" do
      future = create_future("search")._with_timeout(5)

      expect(future.inspect).to eq("#<Future:pending search>")
    end

    it "shows resolved state after success" do
      future = create_future("search")._with_timeout(5)
      future._resolve!("result")

      expect(future.inspect).to match(/#<Future:resolved search => "result"/)
    end
  end
end
