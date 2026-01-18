# Helper for managing fiber context in specs.
#
# In Ruby 3.0+, Thread.current[:key] is fiber-local, not thread-local.
# This helper provides a clean interface for setting the thread-local
# fiber context flag that works correctly across Fibers.
module FiberContextHelper
  FIBER_CONTEXT_KEY = :smolagents_fiber_context

  # Enable fiber context using true thread-local storage.
  def enable_fiber_context
    Thread.current.thread_variable_set(FIBER_CONTEXT_KEY, true)
  end

  # Disable fiber context.
  def disable_fiber_context
    Thread.current.thread_variable_set(FIBER_CONTEXT_KEY, false)
  end

  # Clear fiber context (sets to nil).
  def clear_fiber_context
    Thread.current.thread_variable_set(FIBER_CONTEXT_KEY, nil)
  end

  # Check if fiber context is set.
  def fiber_context_set?
    Thread.current.thread_variable_get(FIBER_CONTEXT_KEY) == true
  end

  # Convenience alias for specs that use set_fiber_context(true/false)
  def set_fiber_context(value) # rubocop:disable Naming/AccessorMethodName
    Thread.current.thread_variable_set(FIBER_CONTEXT_KEY, value)
  end
end

RSpec.configure do |config|
  config.include FiberContextHelper

  # Auto-clear fiber context after each example
  config.after do
    Thread.current.thread_variable_set(:smolagents_fiber_context, nil)
  end
end
