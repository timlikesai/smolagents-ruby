# frozen_string_literal: true

module Smolagents
  class AgentMemory
    attr_reader :system_prompt, :steps

    def initialize(system_prompt)
      @system_prompt = SystemPromptStep.new(system_prompt:)
      @steps = []
    end

    def reset = @steps = []

    def add_task(task, additional_prompting: nil, task_images: nil)
      full_task = additional_prompting ? "#{task}\n\n#{additional_prompting}" : task
      @steps << TaskStep.new(task: full_task, task_images:)
    end

    def to_messages(summary_mode: false)
      system_prompt.to_messages + steps.flat_map { |s| s.to_messages(summary_mode:) }
    end

    def get_succinct_steps = steps.map(&:to_h)
    def get_full_steps = steps.map { |s| s.to_h.merge(full: true) }
    def return_full_code = steps.select { |s| s.is_a?(ActionStep) && s.code_action }.map(&:code_action).join("\n\n")

    def add_step(step) = @steps << step
    alias << add_step
  end
end
