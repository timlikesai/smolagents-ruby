# Experiment: Reasoning and Planning
#
# Test complex reasoning that requires planning, breaking down problems,
# and executing multi-step solutions.
#
# Key capabilities tested:
# 1. Problem decomposition - Breaking complex tasks into steps
# 2. Logical reasoning - Following chains of logic
# 3. Mathematical reasoning - Word problems and calculations
# 4. Strategic planning - Choosing optimal approaches

require_relative "../lib/experiment"
require_relative "../lib/infrastructure"

LiveExperiments::Experiment.define(:reasoning_and_planning) do
  description "Test complex reasoning, planning, and multi-step problem solving"

  models do
    use :fast, :fast_model
    use :reasoning, :reasoning_model
  end

  tools do
    mock :calculate, "Calculate a mathematical expression", expression: String do |expression:|
      sanitized = expression.to_s.gsub(/[^0-9+\-*\/().\s]/, "").strip
      return "Error: invalid expression" if sanitized.empty? || sanitized !~ /\A[\d(]/

      eval(sanitized).to_s # rubocop:disable Security/Eval
    rescue SyntaxError => e
      "Error: invalid syntax - #{e.message}"
    rescue StandardError => e
      "Error: #{e.message}"
    end

    mock :lookup_fact, "Look up a factual piece of information", topic: String do |topic:|
      facts = {
        "speed_of_light" => "299,792,458 meters per second",
        "earth_circumference" => "40,075 kilometers",
        "pi" => "3.14159265359",
        "golden_ratio" => "1.61803398875",
        "avogadro" => "6.022 x 10^23",
        "gravity" => "9.8 m/s^2",
        "water_boiling" => "100 degrees Celsius at sea level",
        "absolute_zero" => "-273.15 degrees Celsius"
      }
      facts[topic.downcase.gsub(" ", "_")] || "Fact not found for '#{topic}'"
    end

    mock :convert_units, "Convert between units", value: Float, from: String, to: String do |value:, from:, to:|
      conversions = {
        ["km", "miles"] => 0.621371,
        ["miles", "km"] => 1.60934,
        ["celsius", "fahrenheit"] => ->(c) { c * 9.0 / 5.0 + 32 },
        ["fahrenheit", "celsius"] => ->(f) { (f - 32) * 5.0 / 9.0 },
        ["kg", "pounds"] => 2.20462,
        ["pounds", "kg"] => 0.453592,
        ["meters", "feet"] => 3.28084,
        ["feet", "meters"] => 0.3048
      }

      key = [from.downcase, to.downcase]
      conversion = conversions[key]
      return "Unknown conversion from #{from} to #{to}" unless conversion

      result = conversion.is_a?(Proc) ? conversion.call(value) : value * conversion
      "#{value} #{from} = #{result.round(2)} #{to}"
    end

    mock :store_value, "Store a named value for later use", name: String, value: String do |name:, value:|
      @stored_values ||= {}
      @stored_values[name] = value
      "Stored '#{name}' = #{value}"
    end

    mock :recall_value, "Recall a previously stored value", name: String do |name:|
      @stored_values ||= {}
      @stored_values[name] || "No value stored for '#{name}'"
    end
  end

  tasks do
    # Basic multi-step reasoning
    task "A train travels at 60 mph for 2.5 hours. How many miles does it travel?",
         validate: ->(output) { output.include?("150") },
         tags: [:word_problem, :arithmetic],
         difficulty: :easy

    task "If a rectangle has a perimeter of 24 cm and one side is 8 cm, what is the area?",
         validate: ->(output) { output.include?("32") }, # Other side is 4, area = 8*4 = 32
         tags: [:word_problem, :geometry],
         difficulty: :medium

    # Multi-step calculations
    task "Calculate 15% tip on a $85 dinner bill, then add it to the bill for the total",
         validate: ->(output) do
           # Tip: 85 * 0.15 = 12.75, Total: 97.75
           output.include?("97.75") || output.include?("97.8")
         end,
         tags: [:percentage, :multi_step],
         difficulty: :medium

    task "A store has a 20% off sale. An item originally costs $150. After the discount, there's 8% sales tax. What's the final price?",
         validate: ->(output) do
           # Discount: 150 * 0.8 = 120, Tax: 120 * 1.08 = 129.6
           output.include?("129.6") || output.include?("129.60")
         end,
         tags: [:percentage, :multi_step],
         difficulty: :medium

    # Unit conversions with reasoning
    task "If I run 5 kilometers, how many miles is that? Look up or convert the distance.",
         validate: ->(output) { output.include?("3.1") }, # 5 * 0.621371 ≈ 3.11
         tags: [:conversion, :lookup],
         difficulty: :easy

    task "Water boils at 100 Celsius. Convert this to Fahrenheit.",
         validate: ->(output) { output.include?("212") },
         tags: [:conversion, :fact_check],
         difficulty: :easy

    # Complex reasoning chains
    task "Look up pi, then calculate the circumference of a circle with radius 10 (formula: 2 * pi * r)",
         validate: ->(output) do
           # 2 * 3.14159 * 10 ≈ 62.83
           output.include?("62.8") || output.include?("62.9") || output.include?("63")
         end,
         tags: [:lookup, :calculation, :formula],
         difficulty: :medium

    task "Look up Earth's circumference in km, then convert it to miles",
         validate: ->(output) do
           # 40,075 km * 0.621371 ≈ 24,901 miles
           output.include?("24") && output.include?("901") ||
             output.include?("24901") || output.include?("24,901") ||
             output.include?("25000") || output.include?("25,000")
         end,
         tags: [:lookup, :conversion, :chain],
         difficulty: :medium

    # Planning and decomposition
    task "To paint a room, you need to: 1) Calculate wall area (room is 12ft x 10ft x 8ft high, 4 walls), 2) One gallon covers 350 sq ft, 3) How many gallons needed?",
         validate: ->(output) do
           # Two 12x8 walls = 192, Two 10x8 walls = 160, Total = 352 sq ft
           # 352 / 350 ≈ 1.0 gallon (need 2 for safety)
           output.include?("1") || output.include?("2")
         end,
         tags: [:planning, :real_world],
         difficulty: :hard

    # Store and recall (working memory)
    task "Store the value '42' as 'answer', then recall it and add 8 to it",
         validate: ->(output) { output.include?("50") },
         tags: [:memory, :multi_step],
         difficulty: :easy
  end

  config do
    iterations 2
    timeout 180
    max_steps 15
    checkpoint_every 1
  end
end
