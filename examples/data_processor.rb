#!/usr/bin/env ruby
# frozen_string_literal: true

# Data Processor Example
#
# A complete example showing how to build an agent that can:
# - Load and process CSV/JSON data
# - Perform calculations and aggregations
# - Generate reports with visualizations (ASCII charts)
# - Export results in multiple formats
#
# This demonstrates the code agent's ability to write Ruby for data analysis.
#
# Usage:
#   OPENAI_API_KEY=sk-... ruby examples/data_processor.rb

require "smolagents"
require "json"
require "csv"

# =============================================================================
# Configuration
# =============================================================================

MODEL_ID = ENV.fetch("MODEL_ID", "gpt-4")
API_KEY = ENV.fetch("OPENAI_API_KEY") { raise "Set OPENAI_API_KEY environment variable" }

# =============================================================================
# Custom Tool: Data Loader
# =============================================================================
#
# Loads sample data for the agent to analyze.

class DataLoaderTool < Smolagents::Tool
  self.tool_name = "load_data"
  self.description = "Load a dataset by name. Available datasets: sales, users, products"
  self.inputs = {
    dataset: { type: "string", description: "Name of the dataset to load" }
  }
  self.output_type = "array"

  DATASETS = {
    "sales" => [
      { date: "2024-01", product: "Widget A", quantity: 150, revenue: 4500.00, region: "North" },
      { date: "2024-01", product: "Widget B", quantity: 200, revenue: 8000.00, region: "South" },
      { date: "2024-02", product: "Widget A", quantity: 180, revenue: 5400.00, region: "North" },
      { date: "2024-02", product: "Widget B", quantity: 220, revenue: 8800.00, region: "South" },
      { date: "2024-03", product: "Widget A", quantity: 160, revenue: 4800.00, region: "East" },
      { date: "2024-03", product: "Widget B", quantity: 190, revenue: 7600.00, region: "West" },
      { date: "2024-03", product: "Widget C", quantity: 50, revenue: 2500.00, region: "North" }
    ],
    "users" => [
      { id: 1, name: "Alice", signups: 45, plan: "pro", active: true },
      { id: 2, name: "Bob", signups: 32, plan: "basic", active: true },
      { id: 3, name: "Carol", signups: 67, plan: "pro", active: true },
      { id: 4, name: "David", signups: 12, plan: "basic", active: false },
      { id: 5, name: "Eve", signups: 89, plan: "enterprise", active: true }
    ],
    "products" => [
      { sku: "WA-001", name: "Widget A", price: 30.00, stock: 500, category: "widgets" },
      { sku: "WB-001", name: "Widget B", price: 40.00, stock: 350, category: "widgets" },
      { sku: "WC-001", name: "Widget C", price: 50.00, stock: 100, category: "widgets" },
      { sku: "GA-001", name: "Gadget A", price: 75.00, stock: 200, category: "gadgets" }
    ]
  }.freeze

  def execute(dataset:)
    data = DATASETS[dataset.downcase]
    raise "Unknown dataset: #{dataset}. Available: #{DATASETS.keys.join(', ')}" unless data

    data
  end
end

# =============================================================================
# Custom Tool: Report Generator
# =============================================================================
#
# Generates formatted reports from analysis results.

class ReportGeneratorTool < Smolagents::Tool
  self.tool_name = "generate_report"
  self.description = "Generate a formatted report from analysis results"
  self.inputs = {
    title: { type: "string", description: "Report title" },
    sections: { type: "array", description: "Array of {heading:, content:} sections" },
    format: { type: "string", description: "Output format: text, markdown, or json", nullable: true }
  }
  self.output_type = "string"

  def execute(title:, sections:, format: "markdown")
    case format.downcase
    when "markdown"
      generate_markdown(title, sections)
    when "json"
      generate_json(title, sections)
    else
      generate_text(title, sections)
    end
  end

  private

  def generate_markdown(title, sections)
    output = ["# #{title}", ""]
    sections.each do |section|
      output << "## #{section[:heading] || section['heading']}"
      output << ""
      output << (section[:content] || section['content']).to_s
      output << ""
    end
    output.join("\n")
  end

  def generate_json(title, sections)
    JSON.pretty_generate({ title: title, sections: sections, generated_at: Time.now.iso8601 })
  end

  def generate_text(title, sections)
    width = 60
    output = ["=" * width, title.center(width), "=" * width, ""]
    sections.each do |section|
      output << (section[:heading] || section['heading']).upcase
      output << "-" * width
      output << (section[:content] || section['content']).to_s
      output << ""
    end
    output.join("\n")
  end
end

# =============================================================================
# Custom Tool: ASCII Chart
# =============================================================================
#
# Creates simple ASCII bar charts for visualization.

class AsciiChartTool < Smolagents::Tool
  self.tool_name = "ascii_chart"
  self.description = "Create an ASCII bar chart from data"
  self.inputs = {
    data: { type: "object", description: "Hash of {label: value} pairs" },
    title: { type: "string", description: "Chart title", nullable: true },
    width: { type: "integer", description: "Maximum bar width in characters", nullable: true }
  }
  self.output_type = "string"

  def execute(data:, title: nil, width: 40)
    return "No data to chart" if data.empty?

    max_value = data.values.map(&:to_f).max
    max_label_length = data.keys.map(&:to_s).map(&:length).max

    lines = []
    lines << title if title
    lines << ""

    data.each do |label, value|
      bar_length = (value.to_f / max_value * width).round
      bar = "" * bar_length
      lines << format("%#{max_label_length}s | %s %s", label, bar, value)
    end

    lines.join("\n")
  end
end

# =============================================================================
# Build the Data Processor Agent
# =============================================================================

model = Smolagents::OpenAIModel.new(
  model_id: MODEL_ID,
  api_key: API_KEY
)

agent = Smolagents.agent(:code)
  .model { model }
  .tools(
    DataLoaderTool.new,
    ReportGeneratorTool.new,
    AsciiChartTool.new,
    :ruby_interpreter
  )
  .max_steps(12)
  .instructions(<<~INSTRUCTIONS)
    You are a data analyst. You can:

    1. Load datasets using load_data (available: sales, users, products)
    2. Process data using ruby_interpreter for calculations
    3. Create visualizations using ascii_chart
    4. Generate reports using generate_report

    When analyzing data:
    - Always start by loading the relevant dataset
    - Show your calculations step by step
    - Include visualizations when helpful
    - Summarize key findings clearly

    For the ruby_interpreter, you can use standard Ruby methods:
    - Array methods: map, select, group_by, sum, etc.
    - Aggregations: count, min, max, sum
    - Calculations: arithmetic, percentages, averages
  INSTRUCTIONS
  .on(:after_step) do |step:, monitor:|
    puts "  Step #{step.step_number} completed (#{monitor.duration.round(2)}s)"
  end
  .build

# =============================================================================
# Run Analysis
# =============================================================================

query = ARGV[0] || "Analyze the sales data. What are the top performing products by revenue? Show a chart of revenue by product."

puts "=" * 70
puts "DATA PROCESSOR"
puts "=" * 70
puts "\nQuery: #{query}"
puts "Model: #{MODEL_ID}"
puts "\nProcessing...\n"

begin
  result = agent.run(query)

  puts "\n" + "=" * 70
  puts "ANALYSIS RESULTS"
  puts "=" * 70
  puts "\n#{result.output}"

  puts "\n" + "-" * 70
  puts "Completed in #{result.steps.count} steps"
  puts "Status: #{result.state}"

rescue Smolagents::AgentError => e
  puts "\nError: #{e.message}"
  exit 1
end

# =============================================================================
# Example Queries to Try
# =============================================================================
#
# 1. "Analyze the sales data and create a report showing revenue trends"
# 2. "Which users have the most signups? Create a chart."
# 3. "Calculate the total stock value for each product category"
# 4. "Compare sales performance across regions"

# =============================================================================
# Notes for Improvement
# =============================================================================
#
# TODO: Consider adding these features:
#
# 1. Data pipeline DSL
#    Smolagents.pipeline
#      .load(:sales)
#      .transform { |d| d.group_by(:product) }
#      .aggregate(:sum, :revenue)
#      .chart(:bar)
#      .run
#
# 2. Built-in data tools
#    - csv_reader, json_reader
#    - data_summarize (auto-detect types, stats)
#    - data_visualize (ASCII + SVG output)
#
# 3. Agent memory for intermediate results
#    - Store computed values between steps
#    - Reference previous calculations
