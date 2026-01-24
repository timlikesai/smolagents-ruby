module Smolagents
  module Concerns
    module GoalTracking
      # Thread-safe goal store with hierarchy support.
      #
      # Maintains goals as execution history. Goals are never evicted -
      # completed goals become part of the historical record. The context
      # provider decides what subset appears in the LLM context.
      #
      # @example Basic usage
      #   store = Store.new
      #   goal = store.add(Types::Goal.create(description: "Find docs"))
      #   store.current  # => goal
      #   store.update(goal.id) { |g| g.complete(evidence: "Done") }
      #   store.current  # => nil (no active goals)
      #   store.size     # => 1 (goal still in history)
      class Store
        def initialize
          @goals = {}
          @root_ids = []
          @mutex = Mutex.new
        end

        # Add a goal to the store.
        # @param goal [Types::Goal] The goal to store
        # @return [Types::Goal] The stored goal
        def add(goal)
          @mutex.synchronize do
            @goals[goal.id] = goal
            @root_ids << goal.id if goal.root?
          end
          goal
        end

        # Update a goal by ID using a block.
        # @param id [String] Goal ID
        # @yield [goal] Block receiving current goal, returning updated goal
        # @return [Types::Goal, nil] Updated goal or nil if not found
        def update(id)
          @mutex.synchronize do
            goal = @goals[id]
            return nil unless goal

            updated = yield(goal)
            @goals[id] = updated
            updated
          end
        end

        # Get goal by ID.
        # @param id [String] Goal ID
        # @return [Types::Goal, nil]
        def get(id)
          @mutex.synchronize { @goals[id] }
        end

        # Get the current (most recent active root) goal.
        # @return [Types::Goal, nil]
        def current
          @mutex.synchronize do
            @root_ids.reverse_each do |id|
              goal = @goals[id]
              return goal if goal&.active?
            end
            nil
          end
        end

        # Get all root goals in creation order.
        # @return [Array<Types::Goal>]
        def roots
          @mutex.synchronize { @root_ids.filter_map { |id| @goals[id] } }
        end

        # Get children of a goal.
        # @param parent_id [String] Parent goal ID
        # @return [Array<Types::Goal>]
        def children_of(parent_id)
          @mutex.synchronize do
            @goals.values.select { |g| g.parent_id == parent_id }
          end
        end

        # Get all active goals.
        # @return [Array<Types::Goal>]
        def active
          @mutex.synchronize { @goals.values.select(&:active?) }
        end

        # Get all open goals (active or blocked).
        # @return [Array<Types::Goal>]
        def open
          @mutex.synchronize { @goals.values.select(&:open?) }
        end

        # Get all completed goals.
        # @return [Array<Types::Goal>]
        def completed
          @mutex.synchronize { @goals.values.select(&:completed?) }
        end

        # Get all goals.
        # @return [Array<Types::Goal>]
        def all
          @mutex.synchronize { @goals.values }
        end

        # Clear all goals (typically for reset between runs).
        # @return [void]
        def clear
          @mutex.synchronize do
            @goals.clear
            @root_ids.clear
          end
        end

        # Number of stored goals.
        # @return [Integer]
        def size
          @mutex.synchronize { @goals.size }
        end

        # Check if store is empty.
        # @return [Boolean]
        def empty?
          @mutex.synchronize { @goals.empty? }
        end
      end
    end
  end
end
