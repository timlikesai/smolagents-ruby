module Smolagents
  module Events
    # Configuration for event class generation.
    EventConfig = Data.define(:predicates, :predicate_field, :freeze_fields, :from_error, :defaults)
  end
end
