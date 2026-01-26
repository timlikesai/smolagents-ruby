# Loader for Smolagents custom RuboCop cops
# These cops enforce our event-driven architecture and Ruby 4.0 idioms
#
# Event-driven cops (avoid timing-dependent code):
# - NoSleep: Forbids sleep() - use Queue.pop or ConditionVariable instead
# - NoTimeoutBlock: Forbids Timeout.timeout - use circuit breakers or events
# - NoTimedWait: Forbids Thread.join(n), cv.wait(m, n) - use untimed versions
# - NoBusyWait: Forbids while Time.now < deadline loops - use blocking waits
# - NoTimingAssertion: Forbids expect(duration).to be >= 0 - test with explicit values
#
# Ruby 4.0 idioms:
# - PreferDataDefine: Prefer Data.define over Struct for immutable value objects
# - PreferEndlessMethod: Prefer def foo? = expr for simple predicates
#
# Code organization:
# - TypeLocationRule: Data.define types must be in lib/smolagents/types/
# - RequireDisableComment: rubocop:disable must have explanation after --

require_relative "smolagents/no_sleep"
require_relative "smolagents/no_timing_assertion"
require_relative "smolagents/no_timeout_block"
require_relative "smolagents/no_timed_wait"
require_relative "smolagents/no_busy_wait"
require_relative "smolagents/prefer_data_define"
require_relative "smolagents/prefer_endless_method"
require_relative "smolagents/type_location_rule"
require_relative "smolagents/require_disable_comment"
require_relative "smolagents/no_reexport_shim"
