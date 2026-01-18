module Smolagents
  module Concerns
    module ReflectionMemory
      # In-memory reflection store with LRU eviction.
      #
      # Thread-safe storage for reflections with automatic eviction
      # when max capacity is reached.
      class Store
        DEFAULT_MAX_REFLECTIONS = 10

        def initialize(max_size: DEFAULT_MAX_REFLECTIONS)
          @max_size = max_size
          @reflections = []
          @mutex = Mutex.new
        end

        # Add a reflection, evicting oldest if at capacity.
        # @param reflection [Smolagents::Types::Reflection] The reflection to store
        # @return [Smolagents::Types::Reflection] The stored reflection
        def add(reflection)
          @mutex.synchronize do
            @reflections.shift while @reflections.size >= @max_size
            @reflections << reflection
          end
          reflection
        end

        # Get all reflections.
        # @return [Array<Smolagents::Types::Reflection>]
        def all
          @mutex.synchronize { @reflections.dup }
        end

        # Get reflections relevant to a task.
        # @param task [String] The current task
        # @param limit [Integer] Maximum reflections to return
        # @return [Array<Smolagents::Types::Reflection>]
        def relevant_to(task, limit: 3)
          @mutex.synchronize do
            @reflections
              .select(&:failure?)
              .sort_by { |r| [-task_similarity(task, r.task), -r.timestamp.to_i] }
              .first(limit)
          end
        end

        # Get only failure reflections.
        # @return [Array<Smolagents::Types::Reflection>]
        def failures
          @mutex.synchronize { @reflections.select(&:failure?) }
        end

        # Clear all reflections.
        # @return [void]
        def clear
          @mutex.synchronize { @reflections.clear }
        end

        # Number of stored reflections.
        # @return [Integer]
        def size
          @mutex.synchronize { @reflections.size }
        end

        private

        # Simple task similarity based on word overlap.
        def task_similarity(task1, task2)
          words1 = task1.to_s.downcase.split(/\W+/).to_set
          words2 = task2.to_s.downcase.split(/\W+/).to_set
          return 0.0 if words1.empty? || words2.empty?

          (words1 & words2).size.to_f / (words1 | words2).size
        end
      end
    end
  end
end
