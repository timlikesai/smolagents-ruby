require "smolagents"

RSpec.describe Smolagents::Types::CancellationToken do
  let(:token) { described_class.new }

  describe "#cancelled?" do
    it "starts uncancelled" do
      expect(token.cancelled?).to be false
    end
  end

  describe "#cancel!" do
    it "sets cancelled to true" do
      token.cancel!
      expect(token.cancelled?).to be true
    end
  end

  describe "#reset!" do
    it "clears cancelled state" do
      token.cancel!
      expect(token.cancelled?).to be true

      token.reset!
      expect(token.cancelled?).to be false
    end
  end

  describe "thread safety", :slow do
    it "handles cancel from another thread" do
      token.cancel!

      thread = Thread.new { token.cancelled? }
      result = thread.value

      expect(result).to be true
    end

    it "handles cancel in one thread, check in main" do
      thread = Thread.new { token.cancel! }
      thread.join

      expect(token.cancelled?).to be true
    end

    it "handles concurrent cancel and reset" do
      threads = Array.new(10) do |i|
        Thread.new do
          if i.even?
            token.cancel!
          else
            token.reset!
          end
        end
      end

      threads.each(&:join)

      # After all threads complete, cancelled? returns a boolean (no crash)
      expect(token.cancelled?).to be(true).or be(false)
    end
  end
end
