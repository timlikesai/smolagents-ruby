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
        def self.for(config)
          case config
          when :memory then Memory.new
          when String then JSONL.new(config)
          else raise ArgumentError, "Unknown backend: #{config.inspect}"
          end
        end

        # In-memory event storage (ephemeral).
        #
        # Fast but not durable. Ideal for testing and short-lived processes.
        class Memory
          def initialize = @events = []

          def append(event)
            @events << event
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

        # JSONL file-based event storage (durable).
        #
        # Appends events as JSON lines with immediate flush for crash safety.
        # Loads existing events on initialization for replay.
        class JSONL
          attr_reader :path

          def initialize(path)
            @path = path
            @events = []
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
            persist(event)
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

          def close
            @file&.close
            @file = nil
          end

          private

          def persist(event)
            ensure_file_open
            @file.puts(event.to_json)
            @file.flush
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

            # Handle timestamp restoration
            data[:created_at] = Time.parse(data[:created_at]) if data[:created_at].is_a?(String)

            # Symbolize known symbol fields (outcome, status, etc.)
            symbolize_fields!(data, %i[outcome status level pattern request_type isolation_mode
                                       resource_type reasoning_mode tool_disclosure])

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
      end
    end
  end
end
