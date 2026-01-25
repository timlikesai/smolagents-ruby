module Smolagents
  module Concerns
    module Orchestration
      module WorkQueue
        # Work dispatch logic - routes work items to appropriate handlers.
        module Dispatch
          private

          def dispatch_work(work_item)
            case work_item.type
            when :model_generate then dispatch_model_generate(work_item)
            when :tool_call then dispatch_tool_call(work_item)
            when :code_execution then dispatch_code_execution(work_item)
            when :sub_agent then dispatch_sub_agent(work_item)
            else raise ArgumentError, "Unknown work type: #{work_item.type}"
            end
          end

          def dispatch_model_generate(work_item)
            respond_to?(:execute_model_generate) ? execute_model_generate(work_item) : work_item.payload
          end

          def dispatch_tool_call(work_item)
            respond_to?(:execute_tool_call) ? execute_tool_call(work_item) : work_item.payload
          end

          def dispatch_code_execution(work_item)
            respond_to?(:execute_code) ? execute_code(work_item) : work_item.payload
          end

          def dispatch_sub_agent(work_item)
            respond_to?(:execute_sub_agent) ? execute_sub_agent(work_item) : work_item.payload
          end

          def build_work_result(work_item, value, duration_ms)
            Types::WorkResult.success(
              work_item_id: work_item.id,
              value:,
              duration_ms:
            )
          end

          def elapsed_ms(start_time)
            ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).to_i
          end
        end
      end
    end
  end
end
