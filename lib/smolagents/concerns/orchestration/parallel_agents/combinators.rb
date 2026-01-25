module Smolagents
  module Concerns
    module Orchestration
      module ParallelAgents
        # Combinator methods for parallel agent execution.
        #
        # Provides spawn_parallel, spawn_race, and spawn_any for different
        # completion strategies when running multiple agents.
        #
        # All methods use event-driven coordination via Queue instead of
        # polling/sleep loops.
        module Combinators
          # Spawns multiple agents and waits for all to complete.
          #
          # @param specs [Array<Hash>] Agent specifications
          # @option specs [Agent] :agent Pre-built agent (optional)
          # @option specs [Symbol] :persona Persona for building agent
          # @option specs [String] :task Task for the agent
          # @option specs [Array] :tools Tools for the agent (optional)
          # @param timeout [Numeric, nil] Overall timeout for all agents
          # @return [Array<Object>] Results from all agents
          # @raise [ParallelExecutionError] If any agent fails
          def spawn_parallel(specs, timeout: nil)
            futures = specs.map { |spec| create_and_start_future(spec, timeout:) }
            wait_for_all(futures)
          end

          # Spawns multiple agents and returns first to complete.
          #
          # Other agents are cancelled once the winner completes.
          #
          # @param specs [Array<Hash>] Agent specifications
          # @param timeout [Numeric, nil] Timeout for completion
          # @return [Object] Result from first completing agent
          # @raise [ParallelExecutionError] If all agents fail
          def spawn_race(specs, timeout: nil)
            futures = specs.map { |spec| create_and_start_future(spec, timeout:) }
            wait_for_first_event_driven(futures)
          end

          # Spawns multiple agents and waits for N to complete.
          #
          # @param specs [Array<Hash>] Agent specifications
          # @param count [Integer] Number of completions required
          # @param timeout [Numeric, nil] Timeout for completion
          # @return [Array<Object>] Results from first N completing agents
          # @raise [ParallelExecutionError] If fewer than N agents succeed
          def spawn_any(specs, count:, timeout: nil)
            raise ArgumentError, "count must be <= specs.size" if count > specs.size

            futures = specs.map { |spec| create_and_start_future(spec, timeout:) }
            wait_for_n_event_driven(futures, count)
          end

          private

          def wait_for_all(futures)
            results = []
            errors = []

            futures.each do |future|
              results << future.value
            rescue StandardError => e
              errors << e
            end

            raise ParallelExecutionError, errors unless errors.empty?

            results
          end

          # Event-driven wait for first completion using Queue.
          # Each future is monitored by a thread that pushes to a shared queue.
          # rubocop:disable Metrics/AbcSize, Metrics/MethodLength -- event-driven coordination requires setup/teardown
          def wait_for_first_event_driven(futures)
            completion_queue = Thread::Queue.new

            # Monitor each future with a thread that signals completion
            monitor_threads = futures.map do |future|
              Thread.new do
                future.value # Block until this future completes
                completion_queue.push(future)
              rescue StandardError
                completion_queue.push(future) # Push even on error
              end
            end

            # Wait for completions, return first success
            completed_count = 0
            errors = []

            futures.size.times do
              future = completion_queue.pop
              completed_count += 1

              if future.success?
                cancel_others(futures, except: future)
                monitor_threads.each(&:kill) # Clean up monitors
                return future.value
              else
                errors << future._error
              end
            end

            # All failed
            monitor_threads.each(&:kill)
            raise ParallelExecutionError, errors.compact
          end
          # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

          # Event-driven wait for N completions using Queue.
          # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity -- event-driven coordination for N completions
          def wait_for_n_event_driven(futures, count)
            completion_queue = Thread::Queue.new

            # Monitor each future
            monitor_threads = futures.map do |future|
              Thread.new do
                future.value
                completion_queue.push(future)
              rescue StandardError
                completion_queue.push(future)
              end
            end

            # Collect successful results
            results = []
            errors = []

            futures.size.times do
              future = completion_queue.pop

              if future.success?
                results << future
                if results.size >= count
                  cancel_others(futures, except: results)
                  monitor_threads.each(&:kill)
                  return results.map(&:value)
                end
              else
                errors << future._error
                # Check if we can still reach count
                remaining_pending = futures.size - (results.size + errors.compact.size)
                break if results.size + remaining_pending < count
              end
            end

            monitor_threads.each(&:kill)
            raise ParallelExecutionError, ["Only #{results.size} of #{count} agents succeeded"]
          end
          # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

          def cancel_others(futures, except:)
            except_set = Array(except)
            futures.each { |f| f.cancel! unless except_set.include?(f) }
          end
        end
      end
    end
  end
end
