RSpec.describe Smolagents::Concerns::Streamable do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::Streamable
    end
  end

  let(:instance) { test_class.new }

  describe "#stream" do
    it "creates a lazy enumerator" do
      result = instance.stream do |yielder|
        yielder << 1
        yielder << 2
        yielder << 3
      end

      expect(result).to be_a(Enumerator::Lazy)
    end

    it "yields values when enumerated" do
      stream = instance.stream do |yielder|
        3.times { |i| yielder << i }
      end

      values = stream.to_a
      expect(values).to eq([0, 1, 2])
    end

    it "is lazy - doesn't execute until consumed" do
      executed = false
      stream = instance.stream do |yielder|
        executed = true
        yielder << "value"
      end

      expect(executed).to be false

      stream.first
      expect(executed).to be true
    end

    it "supports chaining transformations" do
      stream = instance.stream do |yielder|
        5.times { |i| yielder << i }
      end

      result = stream
               .select(&:even?)
               .map { |x| x * 2 }
               .to_a

      expect(result).to eq([0, 4, 8])
    end
  end

  describe "#stream_fiber" do
    it "creates a fiber" do
      fiber = instance.stream_fiber do
        Fiber.yield "value"
      end

      expect(fiber).to be_a(Fiber)
    end

    it "allows bidirectional communication" do
      fiber = instance.stream_fiber do
        input = Fiber.yield "first"
        Fiber.yield "received: #{input}"
      end

      first = fiber.resume
      expect(first).to eq("first")

      second = fiber.resume("user input")
      expect(second).to eq("received: user input")
    end

    it "can be used for pause/resume patterns" do
      steps = []
      fiber = instance.stream_fiber do
        steps << :step1
        Fiber.yield :pause_after_step1

        steps << :step2
        Fiber.yield :pause_after_step2

        steps << :step3
        :done
      end

      expect(fiber.resume).to eq(:pause_after_step1)
      expect(steps).to eq([:step1])

      expect(fiber.resume).to eq(:pause_after_step2)
      expect(steps).to eq(%i[step1 step2])

      expect(fiber.resume).to eq(:done)
      expect(steps).to eq(%i[step1 step2 step3])
    end
  end

  describe "#safe_stream" do
    it "skips errors when on_error is :skip" do
      stream = instance.safe_stream(on_error: :skip) do |yielder|
        yielder << 1
        raise StandardError, "error"
        yielder << 2 # This won't execute due to error
      end

      result = stream.to_a
      expect(result).to eq([1])
    end

    it "stops on error when on_error is :stop" do
      stream = instance.safe_stream(on_error: :stop) do |yielder|
        yielder << 1
        raise StandardError, "stop here"
        yielder << 2
      end

      result = stream.to_a
      expect(result).to eq([1])
    end

    it "calls custom error handler when provided" do
      errors = []
      stream = instance.safe_stream(on_error: ->(e) { errors << e.message }) do |yielder|
        yielder << 1
        raise StandardError, "custom handled"
        yielder << 2
      end

      stream.to_a
      expect(errors).to eq(["custom handled"])
    end

    it "is lazy" do
      executed = false
      stream = instance.safe_stream do |yielder|
        executed = true
        yielder << "value"
      end

      expect(executed).to be false
      stream.first
      expect(executed).to be true
    end
  end

  describe "#merge_streams" do
    it "merges multiple streams sequentially" do
      stream1 = instance.stream { |y| 3.times { |i| y << "a#{i}" } }
      stream2 = instance.stream { |y| 2.times { |i| y << "b#{i}" } }

      merged = instance.merge_streams(stream1, stream2)
      result = merged.to_a

      expect(result).to eq(%w[a0 a1 a2 b0 b1])
    end

    it "handles empty streams" do
      stream1 = instance.stream { |y| y << "value" }
      stream2 = instance.stream { |_y| }

      merged = instance.merge_streams(stream1, stream2)
      expect(merged.to_a).to eq(["value"])
    end

    it "is lazy" do
      executed = { s1: false, s2: false }
      stream1 = instance.stream do |y|
        executed[:s1] = true
        y << 1
      end
      stream2 = instance.stream do |y|
        executed[:s2] = true
        y << 2
      end

      merged = instance.merge_streams(stream1, stream2)
      expect(executed[:s1]).to be false
      expect(executed[:s2]).to be false

      merged.to_a
      expect(executed[:s1]).to be true
      expect(executed[:s2]).to be true
    end
  end

  describe "#transform_stream" do
    it "maps over stream values" do
      stream = instance.stream { |y| 3.times { |i| y << i } }
      transformed = instance.transform_stream(stream) { |x| x * 2 }

      expect(transformed.to_a).to eq([0, 2, 4])
    end

    it "is lazy" do
      executed = false
      stream = instance.stream do |y|
        executed = true
        y << 1
      end

      transformed = instance.transform_stream(stream) { |x| x * 2 }
      expect(executed).to be false

      transformed.first
      expect(executed).to be true
    end
  end

  describe "#filter_stream" do
    it "selects values matching predicate" do
      stream = instance.stream { |y| 5.times { |i| y << i } }
      filtered = instance.filter_stream(stream, &:even?)

      expect(filtered.to_a).to eq([0, 2, 4])
    end

    it "is lazy" do
      executed = false
      stream = instance.stream do |y|
        executed = true
        y << 1
      end

      filtered = instance.filter_stream(stream, &:even?)
      expect(executed).to be false

      filtered.to_a
      expect(executed).to be true
    end
  end

  describe "#take_until" do
    it "takes items until predicate is true" do
      stream = instance.stream { |y| 10.times { |i| y << i } }
      taken = instance.take_until(stream) { |x| x >= 5 }

      expect(taken.to_a).to eq([0, 1, 2, 3, 4])
    end

    it "stops immediately if predicate true on first item" do
      stream = instance.stream do |y|
        y << 10
        y << 20
      end
      taken = instance.take_until(stream) { |x| x >= 10 }

      expect(taken.to_a).to eq([])
    end

    it "is lazy" do
      call_count = 0
      stream = instance.stream do |y|
        10.times do |i|
          call_count += 1
          y << i
        end
      end

      taken = instance.take_until(stream) { |x| x >= 3 }
      taken.to_a

      # Should stop early, not process all 10 items
      expect(call_count).to be < 10
    end
  end

  describe "#batch_stream" do
    it "groups items into batches" do
      stream = instance.stream { |y| 10.times { |i| y << i } }
      batched = instance.batch_stream(stream, size: 3)

      result = batched.to_a
      expect(result).to eq([[0, 1, 2], [3, 4, 5], [6, 7, 8], [9]])
    end

    it "handles exact multiples" do
      stream = instance.stream { |y| 6.times { |i| y << i } }
      batched = instance.batch_stream(stream, size: 3)

      expect(batched.to_a).to eq([[0, 1, 2], [3, 4, 5]])
    end

    it "is lazy" do
      executed = false
      stream = instance.stream do |y|
        executed = true
        y << 1
      end

      batched = instance.batch_stream(stream, size: 2)
      expect(executed).to be false

      batched.first
      expect(executed).to be true
    end
  end

  describe "#collect_stream" do
    it "converts stream to array" do
      stream = instance.stream { |y| 3.times { |i| y << i } }
      result = instance.collect_stream(stream)

      expect(result).to eq([0, 1, 2])
    end

    it "consumes lazy stream" do
      executed = false
      stream = instance.stream do |y|
        executed = true
        y << 1
      end

      instance.collect_stream(stream)
      expect(executed).to be true
    end
  end

  describe "integration example" do
    it "supports complex streaming pipelines" do
      # Simulate agent streaming with multiple transformations
      agent_stream = instance.stream do |yielder|
        10.times do |i|
          yielder << { step: i, status: i.even? ? :success : :pending }
        end
      end

      result = agent_stream
               .select { |item| item[:status] == :success } # Only successful
               .map { |item| item[:step] }                    # Extract step number
               .select { |step| step < 8 }                    # Before step 8
               .to_a

      expect(result).to eq([0, 2, 4, 6])
    end

    it "works with error handling in streaming pipeline" do
      risky_stream = instance.safe_stream(on_error: :skip) do |yielder|
        5.times do |i|
          raise StandardError if i == 2 # Simulate error on third item

          yielder << i
        end
      end

      result = risky_stream.to_a
      expect(result).to eq([0, 1]) # Stops at error
    end

    it "supports pause/resume with fibers for interactive agents" do
      # Simulate interactive agent that waits for user input
      agent_fiber = instance.stream_fiber do
        result1 = process_step_1
        user_input = Fiber.yield result1 # Wait for user confirmation

        result2 = process_step_2(user_input)
        Fiber.yield result2

        :final_result
      end

      def process_step_1
        "Step 1 complete"
      end

      def process_step_2(input)
        "Step 2 with #{input}"
      end

      # Agent produces first result
      step1_result = agent_fiber.resume
      expect(step1_result).to eq("Step 1 complete")

      # User reviews and provides input
      step2_result = agent_fiber.resume("user approval")
      expect(step2_result).to eq("Step 2 with user approval")

      # Agent completes
      final = agent_fiber.resume
      expect(final).to eq(:final_result)
    end

    it "supports batched processing for efficiency" do
      large_stream = instance.stream { |y| 100.times { |i| y << i } }

      batch_count = 0
      instance.batch_stream(large_stream, size: 10).each do |_batch|
        batch_count += 1
        # Process batch...
      end

      expect(batch_count).to eq(10)
    end
  end
end
