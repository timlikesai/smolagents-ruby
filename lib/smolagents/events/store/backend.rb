# Storage backends for EventStore.

module Smolagents
  module Events
    class EventStore
      # Backend factory and implementations for event storage.
      #
      # Backends provide the storage layer for EventStore:
      # - Memory - Fast, ephemeral (for testing)
      # - JSONL - Durable, crash-safe file storage
      module Backend
        # Factory method to create appropriate backend.
        #
        # @param config [:memory, String] Backend configuration
        # @return [Memory, JSONL] Backend instance
        def self.for(config, max_events: nil)
          case config
          when :memory then Memory.new(max_events:)
          when String then JSONL.new(config, max_events:)
          else raise ArgumentError, "Unknown backend: #{config.inspect}"
          end
        end

        # In-memory event storage (ephemeral).
        #
        # Fast but not durable. Ideal for testing and short-lived processes.
        class Memory
          def initialize(max_events: nil)
            @events = []
            @max_events = max_events
          end

          def append(event)
            @events << event
            @events.shift if @max_events && @events.size > @max_events
            event
          end

          def events_in_range(from, to)
            @events.select do |e|
              e.sequence >= from && (to.nil? || e.sequence <= to)
            end
          end

          def count = @events.size
          def all = @events.dup
          def last_sequence = @events.last&.sequence || 0
          def clear = @events.clear
        end

        # JSONL file-based event storage for debugging and development.
        #
        # Reads come from the in-memory +@events+ array (instant).
        # Writes go to a +Thread::Queue+, flushed by a background writer.
        # The writer blocks on +Queue#pop+ — fully evented, no polling.
        # One +IO#flush+ per batch instead of per event.
        #
        # Production systems should use the memory backend with external log shipping.
        #
        # @note Debug/development only — file I/O adds overhead vs pure memory.
        # rubocop:disable Metrics/ClassLength -- file backend with buffered writer
        class JSONL
          attr_reader :path

          # @param path [String] File path for JSONL output
          # @param max_events [Integer, nil] Max in-memory events (nil = unbounded)
          def initialize(path, max_events: nil)
            @path = path
            @events = []
            @max_events = max_events
            @write_queue = Thread::Queue.new
            @write_mutex = Mutex.new
            @thread_mutex = Mutex.new
            @writer = nil
            @file = nil
          end

          def load
            return unless File.exist?(@path)

            File.foreach(@path) do |line|
              event = parse_event(line.strip)
              @events << event if event
            end
          end

          def append(event)
            @events << event
            @events.shift if @max_events && @events.size > @max_events
            @write_queue.push(event)
            ensure_writer_running
            event
          end

          def events_in_range(from, to)
            @events.select do |e|
              e.sequence >= from && (to.nil? || e.sequence <= to)
            end
          end

          def count = @events.size
          def all = @events.dup
          def last_sequence = @events.last&.sequence || 0

          # Force immediate synchronous flush of pending writes.
          def flush = @write_mutex.synchronize { write_batch(drain_remaining) }

          def close
            stop_writer
            flush
            @file&.close
            @file = nil
          end

          private

          def ensure_writer_running
            @thread_mutex.synchronize do
              return if @writer&.alive?

              @writer = Thread.new { writer_loop }
              @writer.name = "JSONL-Writer"
            end
          end

          def stop_writer
            return unless @writer&.alive?

            @write_queue.close
            @writer.join
            @writer = nil
            @write_queue = Thread::Queue.new
          end

          # Blocks on pop — wakes instantly on push or close.
          # Queue#pop returns nil when closed+empty, signaling shutdown.
          def writer_loop
            while (event = @write_queue.pop)
              batch = [event]
              batch.concat(drain_remaining)
              @write_mutex.synchronize { write_batch(batch) }
            end
            # Queue closed — drain any stragglers
            @write_mutex.synchronize { write_batch(drain_remaining) }
          end

          def write_batch(batch)
            return if batch.empty?

            ensure_file_open
            batch.each { |event| @file.puts(event.to_json) }
            @file.flush
          end

          def drain_remaining
            batch = []
            loop { batch << @write_queue.pop(true) }
          rescue ThreadError, ClosedQueueError
            batch
          end

          def ensure_file_open
            return if @file && !@file.closed?

            dir = File.dirname(@path)
            FileUtils.mkdir_p(dir) unless File.directory?(dir)
            @file = File.open(@path, "a")
          end

          def parse_event(line)
            return nil if line.empty?

            data = JSON.parse(line, symbolize_names: true)
            reconstruct(data)
          rescue JSON::ParserError
            nil
          end

          def reconstruct(data)
            type_name = data.delete(:_type)
            return nil unless type_name

            data[:created_at] = Time.parse(data[:created_at]) if data[:created_at].is_a?(String)

            symbolize_fields!(data, %i[outcome status level pattern request_type isolation_mode
                                       resource_type reasoning_mode])

            klass = Object.const_get(type_name)
            klass.new(**data)
          rescue NameError, ArgumentError
            nil
          end

          def symbolize_fields!(data, fields)
            fields.each do |field|
              data[field] = data[field].to_sym if data[field].is_a?(String)
            end
          end
        end
        # rubocop:enable Metrics/ClassLength
      end
    end
  end
end
