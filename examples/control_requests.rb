#!/usr/bin/env ruby
# frozen_string_literal: true

# Control Requests: Handling interactive agent requests
#
# This example demonstrates how to handle control requests from agents and tools:
# - User input requests (prompting for clarification)
# - Confirmation requests (approving potentially dangerous actions)
# - Sub-agent queries (when sub-agents need guidance)
#
# Control requests enable bidirectional communication during Fiber execution,
# allowing agents to pause and ask for human input or approval.

require "smolagents"

# =============================================================================
# Custom Tool with Confirmation
# =============================================================================
#
# Tools can request confirmation before performing potentially dangerous actions.
# The request_confirmation method pauses execution and waits for approval.

class DangerousTool < Smolagents::Tool
  self.tool_name = "dangerous_action"
  self.description = "Performs an action that requires user confirmation"
  self.inputs = {
    action: { type: "string", description: "The action to perform" }
  }
  self.output_type = "string"

  def execute(action:)
    # Request confirmation before proceeding
    # In Fiber mode: yields and waits for response
    # In sync mode: auto-approves if reversible, raises if not
    unless request_confirmation(
      action: "dangerous_action",
      description: "About to perform: #{action}",
      consequences: ["This action may modify system state"],
      reversible: false
    )
      return "Action cancelled by user"
    end

    "Successfully performed: #{action}"
  end
end

# =============================================================================
# Tool with User Input Request
# =============================================================================
#
# Tools can request additional input from the user during execution.

class FileChooserTool < Smolagents::Tool
  self.tool_name = "choose_file"
  self.description = "Asks the user to choose a file from a list"
  self.inputs = {
    pattern: { type: "string", description: "Glob pattern for file matching" }
  }
  self.output_type = "string"

  def execute(pattern:)
    # Simulate finding files
    files = Dir.glob(pattern).take(5)
    return "No files found matching: #{pattern}" if files.empty?

    # Request user input to choose a file
    response = request_user_input(
      prompt: "Choose a file to process",
      context: { pattern: pattern, count: files.size },
      options: files,
      default_value: files.first
    )

    "User selected: #{response}"
  end
end

# =============================================================================
# Generic Control Request Handler
# =============================================================================
#
# A reusable function that handles all types of control requests.

def handle_fiber_execution(fiber)
  loop do
    result = fiber.resume

    case result
    # Handle user input requests
    in Smolagents::Types::ControlRequests::UserInput => req
      puts "\n[User Input Request]"
      puts "Prompt: #{req.prompt}"
      puts "Context: #{req.context}" if req.context&.any?

      if req.has_options?
        puts "Options:"
        req.options.each_with_index { |opt, i| puts "  #{i + 1}. #{opt}" }
        print "Choose (1-#{req.options.size}) > "
        choice = gets.chomp.to_i - 1
        value = req.options[choice] || req.options.first
      else
        print "#{req.prompt} > "
        value = gets.chomp
        value = req.default_value if value.empty? && req.default_value
      end

      response = Smolagents::Types::ControlRequests::Response.respond(
        request_id: req.id,
        value: value
      )
      fiber.resume(response)

    # Handle confirmation requests
    in Smolagents::Types::ControlRequests::Confirmation => req
      puts "\n[Confirmation Required]"
      puts "Action: #{req.action}"
      puts "Description: #{req.description}"
      puts "Consequences: #{req.consequences.join(', ')}" if req.consequences.any?
      puts "Reversible: #{req.reversible}"
      puts "Dangerous: #{req.dangerous?}"

      print "Approve? (y/n) > "
      approved = gets.chomp.downcase == "y"

      response = if approved
                   Smolagents::Types::ControlRequests::Response.approve(request_id: req.id)
                 else
                   Smolagents::Types::ControlRequests::Response.deny(
                     request_id: req.id,
                     reason: "User declined"
                   )
                 end
      fiber.resume(response)

    # Handle sub-agent queries
    in Smolagents::Types::ControlRequests::SubAgentQuery => req
      puts "\n[Sub-Agent Query]"
      puts "Agent: #{req.agent_name}"
      puts "Query: #{req.query}"

      if req.has_options?
        puts "Options: #{req.options.join(', ')}"
        print "Choose or type response > "
      else
        print "Response > "
      end

      value = gets.chomp

      response = Smolagents::Types::ControlRequests::Response.respond(
        request_id: req.id,
        value: value
      )
      fiber.resume(response)

    # Handle action steps (just observe)
    in Smolagents::Types::ActionStep => step
      puts "\n[Step #{step.step_number}]"
      puts "Tools: #{step.tool_calls&.map(&:name)&.join(', ') || 'none'}"
      puts "Observations: #{step.observations&.slice(0, 100)}..." if step.observations

    # Handle final result
    in Smolagents::Types::RunResult => final
      puts "\n[Run Complete]"
      puts "State: #{final.state}"
      puts "Output: #{final.output}"
      return final
    end
  end
end

# =============================================================================
# Interactive Agent Demo
# =============================================================================
#
# Demonstrates handling control requests with custom tools.

def interactive_agent_demo
  puts "=" * 60
  puts "Interactive Agent Demo"
  puts "=" * 60

  agent = Smolagents.code
    .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
    .tools(DangerousTool.new)
    .max_steps(5)
    .build

  fiber = agent.run_fiber("Perform a dangerous action called 'deploy to production'")

  result = handle_fiber_execution(fiber)
  puts "\nFinal output: #{result.output}"
end

# =============================================================================
# File Chooser Demo
# =============================================================================
#
# Demonstrates user input requests with options.

def file_chooser_demo
  puts "\n" + "=" * 60
  puts "File Chooser Demo"
  puts "=" * 60

  agent = Smolagents.code
    .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
    .tools(FileChooserTool.new)
    .max_steps(5)
    .build

  fiber = agent.run_fiber("Choose a Ruby file from the current directory")

  result = handle_fiber_execution(fiber)
  puts "\nFinal output: #{result.output}"
end

# =============================================================================
# Sync Mode Behavior
# =============================================================================
#
# Demonstrates how control requests behave in sync (non-Fiber) mode.
# Reversible confirmations are auto-approved, non-reversible ones raise errors.

# A tool with reversible=true that auto-approves in sync mode
class ReversibleActionTool < Smolagents::Tool
  self.tool_name = "reversible_action"
  self.description = "A reversible action that auto-approves in sync mode"
  self.inputs = { action: { type: "string", description: "Action to perform" } }
  self.output_type = "string"

  def execute(action:)
    unless request_confirmation(
      action: "reversible_action",
      description: action,
      reversible: true  # Will auto-approve in sync mode
    )
      return "Cancelled"
    end
    "Performed: #{action}"
  end
end

def sync_mode_demo
  puts "\n" + "=" * 60
  puts "Sync Mode Behavior"
  puts "=" * 60

  agent = Smolagents.code
    .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
    .tools(ReversibleActionTool.new)
    .max_steps(5)
    .build

  # Run in sync mode - reversible actions auto-approve
  puts "Running with reversible action (auto-approves in sync mode)..."
  result = agent.run("Do a reversible action: backup database")
  puts "Result: #{result.output}"
end

# =============================================================================
# Custom Request Handler
# =============================================================================
#
# Build your own request handler for specific use cases.

class AutoApprover
  def initialize(approve_patterns: [], deny_patterns: [])
    @approve_patterns = approve_patterns
    @deny_patterns = deny_patterns
  end

  def handle(fiber)
    loop do
      result = fiber.resume

      case result
      in Smolagents::Types::ControlRequests::Confirmation => req
        approved = should_approve?(req)
        puts "[AutoApprover] #{req.action}: #{approved ? 'APPROVED' : 'DENIED'}"
        response = approved ?
          Smolagents::Types::ControlRequests::Response.approve(request_id: req.id) :
          Smolagents::Types::ControlRequests::Response.deny(request_id: req.id)
        fiber.resume(response)

      in Smolagents::Types::ControlRequests::UserInput => req
        # Auto-respond with default or first option
        value = req.default_value || req.options&.first || ""
        puts "[AutoApprover] User input: using '#{value}'"
        fiber.resume(Smolagents::Types::ControlRequests::Response.respond(
          request_id: req.id, value: value
        ))

      in Smolagents::Types::ActionStep
        next

      in Smolagents::Types::RunResult => final
        return final
      end
    end
  end

  private

  def should_approve?(req)
    return true if @approve_patterns.any? { |p| req.action.match?(p) }
    return false if @deny_patterns.any? { |p| req.action.match?(p) }

    req.reversible # Default: approve reversible, deny non-reversible
  end
end

def auto_approver_demo
  puts "\n" + "=" * 60
  puts "Auto-Approver Demo"
  puts "=" * 60

  agent = Smolagents.code
    .model { Smolagents::OpenAIModel.new(model_id: "gpt-4") }
    .tools(DangerousTool.new)
    .max_steps(5)
    .build

  # Create auto-approver that approves "backup" actions, denies "delete"
  approver = AutoApprover.new(
    approve_patterns: [/backup/i, /read/i],
    deny_patterns: [/delete/i, /drop/i]
  )

  fiber = agent.run_fiber("Perform a dangerous action: backup database")
  result = approver.handle(fiber)
  puts "Result: #{result.output}"
end

# =============================================================================
# Run Examples
# =============================================================================

if __FILE__ == $PROGRAM_NAME
  puts "Smolagents Control Requests Examples"
  puts "====================================\n"

  # Comment out examples you don't want to run
  # (they require API keys and make real requests)

  begin
    interactive_agent_demo
    # file_chooser_demo
    # sync_mode_demo
    # auto_approver_demo
  rescue StandardError => e
    puts "Error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    puts "(Make sure you have OPENAI_API_KEY set)"
  end
end
