module Smolagents
  module Concerns
    module Orchestration
      module ParallelAgents
        # Combinator methods for parallel agent execution.
        #
        # Provides spawn_parallel, spawn_race, and spawn_any for different
        # completion strategies when running multiple agents.
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
            wait_for_first(futures)
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
            wait_for_n(futures, count)
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

          # rubocop:disable Metrics/MethodLength -- polling loop for first completion
          def wait_for_first(futures)
            loop do
              futures.each do |future|
                next unless future._resolved?

                cancel_others(futures, except: future)
                return future.value if future.success?
              end

              completed = futures.select(&:_resolved?)
              break if completed.size == futures.size

              sleep 0.01 # rubocop:disable Smolagents/NoSleep -- polling for completion
            end

            raise ParallelExecutionError, futures.filter_map(&:_error)
          end
          # rubocop:enable Metrics/MethodLength

          # rubocop:disable Metrics -- inherent complexity for N-of-M completion
          def wait_for_n(futures, count)
            results = []

            loop do
              futures.each do |future|
                next unless future._resolved? && future.success? && !results.include?(future)

                results << future
                if results.size >= count
                  cancel_others(futures, except: results)
                  return results.map(&:value)
                end
              end

              pending = futures.reject(&:_resolved?)
              remaining_possible = pending.size + results.size
              break if remaining_possible < count

              sleep 0.01 # rubocop:disable Smolagents/NoSleep -- polling for completion
            end

            raise ParallelExecutionError, ["Only #{results.size} of #{count} agents succeeded"]
          end
          # rubocop:enable Metrics

          def cancel_others(futures, except:)
            except_set = Array(except)
            futures.each { |f| f.cancel! unless except_set.include?(f) }
          end
        end
      end
    end
  end
end
