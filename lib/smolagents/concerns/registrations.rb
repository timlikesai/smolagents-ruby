# Concern registrations organized by category.
#
# This file registers all concerns with the Registry, providing:
# - Metadata for introspection
# - Dependency tracking
# - Documentation generation
#
# @see Registry For the registration API
# @see Smolagents.concerns For querying registered concerns
require_relative "registrations/agents"
require_relative "registrations/resilience"
require_relative "registrations/execution"
require_relative "registrations/infrastructure"
require_relative "registrations/compression"
