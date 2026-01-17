# Ractor Types: Immutable data structures for Ractor-based concurrent execution.
#
# This file serves as an index, loading all Ractor type definitions from the
# ractor/ subdirectory.
#
# == Ractor Shareability Rules for Data.define Types
#
# Data.define objects ARE Ractor-shareable when ALL their values are shareable.
# This is a critical architectural constraint for any code using Ractors.
#
# == Shareable Values
#
# * Primitives: Integer, Float, Symbol, nil, true, false
# * Frozen strings: "hello".freeze or frozen string literals
# * Frozen arrays/hashes with shareable contents
# * Nested Data.define objects (if their values are shareable)
# * Class/Module references
#
# == NOT Shareable
#
# * Unfrozen strings (use .freeze or Ractor.make_shareable)
# * Procs/Lambdas (NEVER shareable as values)
# * Arbitrary object instances (unless explicitly made shareable)
#
# == Key Insight
#
# Custom methods defined in a Data.define block do NOT affect shareability.
# Methods are stored on the class, not as Procs in the instance.
#
# == Types Provided
#
# * RactorTask - Task submitted to a child Ractor
# * RactorSuccess - Successful result from a sub-agent Ractor
# * RactorFailure - Failed result from a sub-agent Ractor
# * RactorMessage - Message envelope for type-safe communication
# * OrchestratorResult - Aggregated result from parallel execution
#
# @see PLAN.md "Data.define Ractor Shareability" for comprehensive documentation

require_relative "ractor/task"
require_relative "ractor/success"
require_relative "ractor/failure"
require_relative "ractor/message"
require_relative "ractor/orchestrator_result"
