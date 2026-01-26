module Smolagents
  module Concerns
    module Planning
      # Default templates based on Pre-Act research (arXiv:2505.09970).
      #
      # Templates use format string placeholders (%<name>s):
      # - :initial_plan - task, tools
      # - :update_plan_pre - task
      # - :update_plan_post - task, steps, observations, plan
      # - :planning_system - (no placeholders)
      module Templates
        TEMPLATES = {
          initial_plan: <<~PROMPT,
            Create a step-by-step plan to complete this task.

            Task: %<task>s

            Available tools:
            %<tools>s

            Instructions:
            - Create 3-5 concrete steps
            - Each step should use one of the available tools
            - Be specific about what information to gather or actions to take
            - Number each step

            Plan:
          PROMPT

          update_plan_pre: <<~PROMPT,
            Review your progress and update your plan.

            Task: %<task>s
          PROMPT

          update_plan_post: <<~PROMPT,
            Progress so far:
            %<steps>s

            Latest observations:
            %<observations>s

            Current plan:
            %<plan>s

            Based on what you've learned, either:
            1. Confirm the plan is still valid and continue, OR
            2. Update the remaining steps based on new information

            Updated plan:
          PROMPT

          planning_system: <<~PROMPT.gsub(/\s+/, " ").strip
            You are a strategic planning assistant.
            Create concise, actionable plans that map directly to available tools.
            Focus on concrete steps, not abstract strategies.
          PROMPT
        }.freeze
      end
    end
  end
end
