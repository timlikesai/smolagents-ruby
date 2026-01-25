RSpec.describe Smolagents::Executors::RactorLazy do
  let(:executor) { Smolagents::Executors::Ractor.new }

  after { executor.shutdown! }

  def simple_tool(name, &)
    Class.new(Smolagents::Tool) do
      self.tool_name = name
      self.description = "Test tool"
      self.inputs = { value: { type: "string", description: "Input" } }
      self.output_type = "string"
      define_method(:execute, &)
    end.new
  end

  describe "lazy tool futures" do
    it "returns futures immediately without blocking" do
      call_count = 0
      mutex = Mutex.new
      tool = simple_tool("tracked") do |value:|
        mutex.synchronize { call_count += 1 }
        "result-#{value}"
      end
      executor.send_tools("tracked" => tool)

      # Tool calls return immediately (futures), resolution happens on access
      code = <<~RUBY
        @a = tracked(value: "1")
        @b = tracked(value: "2")
        @a + @b  # Force resolution
      RUBY

      result = executor.execute(code, language: :ruby)
      expect(result.error).to be_nil
      expect(result.output).to eq "result-1result-2"
      expect(call_count).to eq 2
    end

    it "resolves on method access" do
      tool = simple_tool("echo") { |value:| value.upcase }
      executor.send_tools("echo" => tool)

      code = <<~RUBY
        @result = echo(value: "hello")
        @result.length  # Access triggers resolution
      RUBY

      result = executor.execute(code, language: :ruby)
      expect(result.error).to be_nil
      expect(result.output).to eq 5
    end

    it "resolves on comparison" do
      tool = simple_tool("number") { |value:| value.to_i * 2 }
      executor.send_tools("number" => tool)

      code = <<~RUBY
        @result = number(value: "5")
        @result == 10
      RUBY

      result = executor.execute(code, language: :ruby)
      expect(result.error).to be_nil
      expect(result.output).to be true
    end

    it "resolves on to_s" do
      tool = simple_tool("greet") { |value:| "Hello #{value}" }
      executor.send_tools("greet" => tool)

      code = <<~RUBY
        @result = greet(value: "World")
        "Message: " + @result.to_s
      RUBY

      result = executor.execute(code, language: :ruby)
      expect(result.error).to be_nil
      expect(result.output).to eq "Message: Hello World"
    end
  end

  describe "automatic batching" do
    it "batches multiple tool calls together" do
      call_order = []
      tool = simple_tool("track") do |value:|
        call_order << value
        "done-#{value}"
      end
      executor.send_tools("track" => tool)

      code = <<~RUBY
        @a = track(value: "first")
        @b = track(value: "second")
        @c = track(value: "third")
        @a + @b + @c  # Single access resolves all
      RUBY

      result = executor.execute(code, language: :ruby)
      expect(result.error).to be_nil
      expect(result.output).to eq "done-firstdone-seconddone-third"
      expect(call_order).to eq %w[first second third]
    end

    it "executes batch within tight time window" do
      call_times = []
      tool = simple_tool("timed") do |value:|
        call_times << Time.now.to_f
        value
      end
      executor.send_tools("timed" => tool)

      code = <<~RUBY
        @a = timed(value: "1")
        @b = timed(value: "2")
        @c = timed(value: "3")
        @a.to_s  # Trigger batch
      RUBY

      executor.execute(code, language: :ruby)
      expect(call_times.length).to eq 3

      # All calls should happen within 5ms of each other (batched)
      time_spread = call_times.max - call_times.min
      expect(time_spread).to be < 0.005
    end

    it "handles sequential batches" do
      tool = simple_tool("batch") { |value:| value.to_i }
      executor.send_tools("batch" => tool)

      code = <<~RUBY
        # First batch
        @a = batch(value: "1")
        @b = batch(value: "2")
        first_sum = @a + @b  # Resolve batch 1

        # Second batch
        @c = batch(value: "3")
        @d = batch(value: "4")
        second_sum = @c + @d  # Resolve batch 2

        [first_sum, second_sum]
      RUBY

      result = executor.execute(code, language: :ruby)
      expect(result.error).to be_nil
      expect(result.output).to eq [3, 7]
    end
  end

  describe "array operations on futures" do
    it "supports first" do
      tool = simple_tool("list") { |**| [1, 2, 3] }
      executor.send_tools("list" => tool)

      result = executor.execute("@r = list(value: 'x'); @r.first", language: :ruby)
      expect(result.output).to eq 1
    end

    it "supports indexing" do
      tool = simple_tool("list") { |**| %w[a b c] }
      executor.send_tools("list" => tool)

      result = executor.execute("@r = list(value: 'x'); @r[1]", language: :ruby)
      expect(result.output).to eq "b"
    end

    it "supports each" do
      tool = simple_tool("list") { |**| [1, 2, 3] }
      executor.send_tools("list" => tool)

      code = <<~RUBY
        @r = list(value: "x")
        sum = 0
        @r.each { |n| sum += n }
        sum
      RUBY

      result = executor.execute(code, language: :ruby)
      expect(result.output).to eq 6
    end

    it "supports map" do
      tool = simple_tool("list") { |**| [1, 2, 3] }
      executor.send_tools("list" => tool)

      result = executor.execute("@r = list(value: 'x'); @r.map { |n| n * 2 }", language: :ruby)
      expect(result.output).to eq [2, 4, 6]
    end
  end

  describe "hash operations on futures" do
    it "supports key access" do
      tool = simple_tool("data") { |**| { "name" => "test", "count" => 42 } }
      executor.send_tools("data" => tool)

      result = executor.execute('@r = data(value: "x"); @r["name"]', language: :ruby)
      expect(result.output).to eq "test"
    end

    it "supports to_h" do
      tool = simple_tool("data") { |**| { a: 1 } }
      executor.send_tools("data" => tool)

      result = executor.execute("@r = data(value: 'x'); @r.to_h", language: :ruby)
      expect(result.output).to eq({ a: 1 })
    end
  end

  describe "error handling" do
    it "propagates tool errors" do
      tool = simple_tool("failing") { |**| raise "Tool failed!" }
      executor.send_tools("failing" => tool)

      result = executor.execute("@r = failing(value: 'x'); @r.to_s", language: :ruby)
      expect(result.error).to include("Tool failed!")
    end

    it "handles errors in batch without affecting other futures" do
      call_count = 0
      tool = simple_tool("maybe_fail") do |value:|
        call_count += 1
        raise "Failed!" if value == "fail"

        "ok-#{value}"
      end
      executor.send_tools("maybe_fail" => tool)

      code = <<~RUBY
        @good = maybe_fail(value: "good")
        @bad = maybe_fail(value: "fail")
        begin
          @bad.to_s
        rescue => e
          "caught: " + e.message
        end
      RUBY

      result = executor.execute(code, language: :ruby)
      expect(result.output).to include("Failed!")
      expect(call_count).to eq 2 # Both were called in batch
    end
  end

  describe "persistence across executions" do
    it "persists instance variables with resolved futures" do
      tool = simple_tool("compute") { |value:| value.to_i * 2 }
      executor.send_tools("compute" => tool)

      executor.execute("@result = compute(value: '5'); @result.to_i", language: :ruby)
      result = executor.execute("@result + 10", language: :ruby)

      expect(result.error).to be_nil
      expect(result.output).to eq 20
    end

    it "allows new tool calls in subsequent executions", max_time: 0.06 do
      tool = simple_tool("inc") { |value:| value.to_i + 1 }
      executor.send_tools("inc" => tool)

      executor.execute("@a = inc(value: '1'); @a.to_i", language: :ruby)
      result = executor.execute("@b = inc(value: @a.to_s); @b", language: :ruby)

      expect(result.error).to be_nil
      expect(result.output).to eq 3 # 1 + 1 = 2, 2 + 1 = 3
    end
  end

  describe "final_answer integration" do
    let(:final_answer_tool) do
      Class.new(Smolagents::Tool) do
        self.tool_name = "final_answer"
        self.description = "Return final answer"
        self.inputs = { answer: { type: "string", description: "Answer" } }
        self.output_type = "string"

        def execute(answer:)
          raise Smolagents::FinalAnswerException, answer
        end
      end.new
    end

    it "handles final_answer in batch", max_time: 0.06 do
      tool = simple_tool("search") { |value:| "found: #{value}" }
      executor.send_tools("search" => tool, "final_answer" => final_answer_tool)

      code = <<~RUBY
        @result = search(value: "query")
        final_answer(answer: @result)
      RUBY

      result = executor.execute(code, language: :ruby)
      expect(result.error).to be_nil
      expect(result.final_answer).to be true
      expect(result.output).to eq "found: query"
    end
  end
end
