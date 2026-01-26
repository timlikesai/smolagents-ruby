# Experiment: Multi-Model Patterns
#
# Test tiered reasoning and research swarm patterns with real infrastructure.

require_relative "../lib/experiment"
require_relative "../lib/infrastructure"

LiveExperiments::Experiment.define(:multi_model_patterns) do
  description "Test multi-model orchestration patterns: tiered reasoning and research swarm"

  models do
    # Tiered pattern: fast for triage, big for complex
    add :tiered do
      fast = LiveExperiments::Infrastructure::ModelFactories.fast_model
      big = LiveExperiments::Infrastructure::ModelFactories.reasoning_model

      # Build a tiered agent
      Smolagents.agent
                .model(:execution) { fast }
                .model(:planning) { big }
                .planning(interval: 3)
                .max_steps(15)
                .build
                .instance_variable_get(:@models)[:execution] # Return the fast model for now
    end

    # Single fast model baseline
    use :fast_baseline, :fast_model

    # Single reasoning model baseline
    use :reasoning_baseline, :reasoning_model
  end

  tools do
    mock :research, "Research a topic deeply", topic: String do |topic:|
      <<~RESEARCH
        Research findings on '#{topic}':

        Overview:
        #{topic} is a significant concept in its field with multiple applications.

        Key Points:
        1. Historical development and evolution
        2. Core principles and mechanisms
        3. Current applications and use cases
        4. Future directions and challenges

        Sources consulted: Wikipedia, academic papers, industry reports
      RESEARCH
    end

    mock :analyze, "Analyze data or information", data: String do |data:|
      "Analysis of provided data:\n" \
        "- Length: #{data.length} characters\n" \
        "- Key themes identified\n" \
        "- Patterns recognized\n" \
        "- Recommendations based on analysis"
    end

    mock :summarize, "Summarize information concisely", text: String do |text:|
      words = text.split
      "Summary (#{words.size} words compressed):\n" \
        "#{words.first(20).join(" ")}..." \
        "\n\nKey takeaways:\n" \
        "1. Main point identified\n" \
        "2. Supporting evidence noted\n" \
        "3. Conclusion drawn"
    end
  end

  tasks do
    # Simple tasks - should be handled by fast model
    task "What is 2 + 2?",
         expect: "4",
         tags: [:simple, :math],
         difficulty: :easy

    task "Define the term 'algorithm' in one sentence",
         validate: ->(output) { output.downcase.include?("step") || output.downcase.include?("instruction") },
         tags: [:simple, :definition],
         difficulty: :easy

    # Medium complexity - might need some reasoning
    task "Research the topic of 'machine learning' and provide a brief summary",
         validate: ->(output) { output.downcase.include?("machine") && output.downcase.include?("learning") },
         tags: [:research, :medium],
         difficulty: :medium

    task "Analyze the advantages and disadvantages of remote work",
         validate: ->(output) { output.downcase.include?("advantage") || output.downcase.include?("benefit") || output.downcase.include?("pro") },
         tags: [:analysis, :medium],
         difficulty: :medium

    # Complex tasks - should benefit from planning/big model
    task "Research Ruby's Ractor API, analyze its use cases, and summarize when it should be used versus traditional threading",
         validate: ->(output) do
           lower = output.downcase
           lower.include?("ractor") && (lower.include?("parallel") || lower.include?("concurrent"))
         end,
         tags: [:complex, :multi_step],
         difficulty: :hard

    task "Compare and contrast three different sorting algorithms (quicksort, mergesort, heapsort), then recommend which to use for a dataset of 1 million integers",
         validate: ->(output) do
           lower = output.downcase
           lower.include?("sort") && (lower.include?("quick") || lower.include?("merge") || lower.include?("heap"))
         end,
         tags: [:complex, :comparison],
         difficulty: :hard
  end

  config do
    iterations 2
    timeout 180
    max_steps 20
    checkpoint_every 1
  end
end
