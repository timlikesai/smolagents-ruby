# frozen_string_literal: true

module Smolagents
  # Base class for multi-step reasoning agents implementing ReAct loop.
  class MultiStepAgent
    include Concerns::Monitorable

    attr_reader :tools, :model, :memory, :max_steps, :logger, :state, :managed_agents, :planning_interval

    PLANNING_PROMPT = <<~PROMPT
      Based on the task and your progress so far, create or update your plan.
      Task: %<task>s
      Previous steps taken:
      %<steps>s
      Current observations:
      %<observations>s
      Create a brief plan (3-5 bullet points) for completing this task:
    PROMPT

    def initialize(tools:, model:, max_steps: 20, managed_agents: nil, planning_interval: nil, logger: nil)
      @model = model
      @max_steps = max_steps
      @logger = logger || Monitoring::AgentLogger.new(output: $stderr, level: Monitoring::AgentLogger::WARN)
      @state = {}
      @planning_interval = planning_interval
      @current_plan = nil

      @managed_agents = (managed_agents || []).to_h do |a|
        t = a.is_a?(ManagedAgentTool) ? a : ManagedAgentTool.new(agent: a)
        [t.name, t]
      end
      @tools = tools.to_h { |t| [t.name, t] }.merge(@managed_agents)
      @memory = AgentMemory.new(system_prompt)
    end

    def run(task, stream: false, reset: true, images: nil, additional_prompting: nil)
      Instrumentation.instrument("smolagents.agent.run", task: task, agent_class: self.class.name) do
        if reset
          (@memory.reset
           @state = {})
        end
        @task_images = images
        if stream
          run_stream(task: task, additional_prompting: additional_prompting,
                     images: images)
        else
          run_sync(task: task, additional_prompting: additional_prompting, images: images)
        end
      end
    end

    def register_callback(event, &) = callbacks_registry.register(event, &)
    def write_memory_to_messages(summary_mode: false) = @memory.to_messages(summary_mode: summary_mode)
    def step(task, step_number: 0) = raise(NotImplementedError, "#{self.class}#step must be implemented")
    def system_prompt = raise(NotImplementedError, "#{self.class}#system_prompt must be implemented")

    private

    def run_sync(task:, additional_prompting: nil, images: nil)
      @memory.add_task(task, additional_prompting: additional_prompting, task_images: images)
      step_number = 1
      total_tokens = TokenUsage.new(input_tokens: 0, output_tokens: 0)
      overall_timing = Timing.start_now

      while step_number <= @max_steps
        @logger.step_start(step_number)
        callbacks_registry.trigger(:step_start, step_number)

        current_step = nil
        monitor_step("step_#{step_number}") do
          Instrumentation.instrument("smolagents.agent.step", step_number: step_number, agent_class: self.class.name) do
            current_step = step(task, step_number: step_number)
            @memory.add_step(current_step)
            total_tokens = accumulate_tokens(total_tokens, current_step.token_usage)
            current_step
          end
        end

        callbacks_registry.trigger(:step_complete, current_step, step_monitors["step_#{step_number}"])
        @logger.step_complete(step_number, duration: step_monitors["step_#{step_number}"].duration)

        return build_result(current_step.action_output, :success, total_tokens, overall_timing.stop) if current_step.is_final_answer

        if @planning_interval && (step_number % @planning_interval).zero?
          planning_step = execute_planning_step(task, current_step)
          @memory.add_step(planning_step)
          total_tokens = accumulate_tokens(total_tokens, planning_step.token_usage)
        end

        step_number += 1
      end

      callbacks_registry.trigger(:max_steps_reached, step_number - 1)
      @logger.warn("Max steps reached", max_steps: @max_steps)
      build_result(nil, :max_steps_reached, total_tokens, overall_timing.stop)
    rescue StandardError => e
      @logger.error("Agent error", error: e.message, backtrace: e.backtrace.first(3))
      build_result(nil, :error, total_tokens, overall_timing.stop)
    end

    def run_stream(task:, additional_prompting: nil, images: nil)
      Enumerator.new do |yielder|
        @memory.add_task(task, additional_prompting: additional_prompting, task_images: images)
        step_number = 1

        while step_number <= @max_steps
          callbacks_registry.trigger(:step_start, step_number)
          current_step = step(task, step_number: step_number)
          @memory.add_step(current_step)

          yielder << current_step
          callbacks_registry.trigger(:step_complete, current_step, nil)
          break if current_step.is_final_answer

          step_number += 1
        end

        callbacks_registry.trigger(:max_steps_reached, step_number - 1) if step_number > @max_steps
      end
    end

    def execute_planning_step(task, last_step)
      timing = Timing.start_now
      steps_summary = @memory.steps.select { |s| s.is_a?(ActionStep) }.map { |s| "Step #{s.step_number}: #{s.observations&.slice(0, 100)}..." }.join("\n")
      planning_messages = [
        ChatMessage.system("You are a planning assistant. Create concise, actionable plans."),
        ChatMessage.user(format(PLANNING_PROMPT, task: task, steps: steps_summary.empty? ? "None yet." : steps_summary,
                                                 observations: last_step.observations || "No observations yet."))
      ]
      response = @model.generate(planning_messages)
      @current_plan = response.content
      PlanningStep.new(model_input_messages: planning_messages, model_output_message: response, plan: @current_plan, timing: timing.stop, token_usage: response.token_usage)
    end

    def accumulate_tokens(total,
                          usage)
      usage ? TokenUsage.new(input_tokens: total.input_tokens + usage.input_tokens, output_tokens: total.output_tokens + usage.output_tokens) : total
    end

    def build_result(output, state, tokens, timing)
      RunResult.new(output: output, state: state, steps: @memory.steps.dup, token_usage: tokens, timing: timing).tap do |result|
        callbacks_registry.trigger(:task_complete, result) if state == :success
      end
    end
  end
end
