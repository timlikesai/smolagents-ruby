# Experiment: Tool Chaining
#
# Test how well agents combine multiple tools to accomplish complex tasks.
# This is critical for real-world usefulness - most tasks require multiple steps.
#
# Key capabilities tested:
# 1. Sequential tool calls (output of one feeds into another)
# 2. Parallel tool calls (multiple independent operations)
# 3. Conditional tool use (deciding which tool based on results)
# 4. Aggregating results from multiple tools

require_relative "../lib/experiment"
require_relative "../lib/infrastructure"

LiveExperiments::Experiment.define(:tool_chaining) do
  description "Test multi-tool task completion and tool composition"

  models do
    use :fast, :fast_model
    use :reasoning, :reasoning_model
  end

  tools do
    # Data retrieval tools
    # NOTE: Tool descriptions include return value structure to help LLMs extract data correctly
    mock :get_user,
         "Get user information by ID. Returns hash with keys: name, email, department, salary (integer). If user not found, returns hash with key: error",
         user_id: Integer do |user_id:|
      users = {
        1 => { "name" => "Alice", "email" => "alice@example.com", "department" => "Engineering", "salary" => 85_000 },
        2 => { "name" => "Bob", "email" => "bob@example.com", "department" => "Marketing", "salary" => 72_000 },
        3 => { "name" => "Carol", "email" => "carol@example.com", "department" => "Engineering", "salary" => 92_000 },
        4 => { "name" => "Dave", "email" => "dave@example.com", "department" => "Sales", "salary" => 78_000 },
        5 => { "name" => "Eve", "email" => "eve@example.com", "department" => "Engineering", "salary" => 88_000 }
      }
      users[user_id] || { "error" => "User not found" }
    end

    mock :get_department_budget,
         "Get budget for a department. Returns hash with keys: department, budget (integer), year",
         department: String do |department:|
      budgets = {
        "Engineering" => 500_000,
        "Marketing" => 200_000,
        "Sales" => 300_000,
        "HR" => 150_000
      }
      { "department" => department, "budget" => budgets[department] || 0, "year" => 2026 }
    end

    mock :list_users_in_department,
         "List all users in a department. Returns array of hashes with keys: id, name, department",
         department: String do |department:|
      all_users = [
        { "id" => 1, "name" => "Alice", "department" => "Engineering" },
        { "id" => 2, "name" => "Bob", "department" => "Marketing" },
        { "id" => 3, "name" => "Carol", "department" => "Engineering" },
        { "id" => 4, "name" => "Dave", "department" => "Sales" },
        { "id" => 5, "name" => "Eve", "department" => "Engineering" }
      ]
      all_users.select { |u| u["department"] == department }
    end

    # Transformation tools
    mock :calculate, "Calculate a mathematical expression", expression: String do |expression:|
      sanitized = expression.to_s.gsub(/[^0-9+\-*\/().\s]/, "").strip
      return "Error: invalid expression" if sanitized.empty? || sanitized !~ /\A[\d(]/

      eval(sanitized).to_s # rubocop:disable Security/Eval
    rescue SyntaxError => e
      "Error: invalid syntax - #{e.message}"
    rescue StandardError => e
      "Error: #{e.message}"
    end

    mock :format_currency, "Format a number as currency", amount: Integer do |amount:|
      "$#{amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    end

    mock :send_email, "Send an email (simulated)", to: String, subject: String, body: String do |to:, subject:, body:|
      "Email sent to #{to} with subject '#{subject}' (#{body.length} chars)"
    end

    # Analysis tools
    mock :compare_values, "Compare two values", a: Integer, b: Integer do |a:, b:|
      diff = a - b
      pct = b.positive? ? ((diff.to_f / b) * 100).round(1) : 0
      {
        "a" => a, "b" => b, "difference" => diff,
        "percentage_change" => "#{pct}%",
        "comparison" => a > b ? "a is larger" : (a < b ? "b is larger" : "equal")
      }
    end
  end

  tasks do
    # Sequential chaining (A -> B -> C)
    task "Get user 1's information, then get their department's budget, and format the budget as currency",
         validate: ->(output) { output.include?("$") && output.include?("500") },
         tags: [:sequential, :three_step],
         difficulty: :medium

    task "Get user 3's salary, calculate 10% of it (bonus), and format as currency",
         validate: ->(output) { output.include?("$") && output.include?("9,200") },
         tags: [:sequential, :calculation],
         difficulty: :medium

    # Parallel then aggregate
    task "Get the budgets for Engineering and Marketing departments, then calculate the total",
         validate: ->(output) { output.include?("700000") || output.include?("700,000") },
         tags: [:parallel, :aggregation],
         difficulty: :medium

    task "Get users 1 and 3, compare their salaries, and report who earns more",
         validate: ->(output) do
           low = output.downcase
           # Carol earns more ($92k vs $85k) - accept various ways to express this
           (low.include?("carol") || low.include?("user 3") || output.include?("92")) &&
             (low.include?("more") || low.include?("higher") || low.include?("larger") || low.include?("earn"))
         end,
         tags: [:parallel, :comparison],
         difficulty: :medium

    # Conditional logic
    task "Get user 2's department, then list all users in that department",
         validate: ->(output) { output.downcase.include?("bob") && output.downcase.include?("marketing") },
         tags: [:conditional, :lookup],
         difficulty: :easy

    task "List users in Engineering, get each person's salary, and calculate the total salary expense",
         validate: ->(output) do
           # Alice: 85000, Carol: 92000, Eve: 88000 = 265000
           output.include?("265000") || output.include?("265,000")
         end,
         tags: [:iteration, :aggregation],
         difficulty: :hard

    # Complex multi-step with output
    task "Get user 1's info, compose an email to them about their department's budget (include the actual budget amount)",
         validate: ->(output) do
           output.downcase.include?("alice") &&
             (output.include?("500000") || output.include?("500,000") || output.include?("$500"))
         end,
         tags: [:multi_step, :composition],
         difficulty: :medium

    # Error handling in chains
    task "Try to get user 99 (doesn't exist), and if not found, get user 1 instead and report their name",
         validate: ->(output) { output.downcase.include?("alice") },
         tags: [:error_handling, :fallback],
         difficulty: :medium
  end

  config do
    iterations 2
    timeout 180
    max_steps 15
    checkpoint_every 1
  end
end
