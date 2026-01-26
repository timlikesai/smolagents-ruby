# Layered context model for agent message assembly.
#
# Defines priority layers that control context ordering and truncation behavior.
# Higher priority layers are included first and survive truncation.
#
# @example Access layer by name
#   Layer[:strategic]  #=> Layer::STRATEGIC
#
# @example Pattern matching
#   case layer
#   in Layer(survives_truncation: true) then "always include"
#   else "may truncate"
#   end
module Smolagents
  module Context
    Layer = Data.define(:id, :name, :priority, :survives_truncation)

    class Layer
      SYSTEM     = new(id: 0, name: :system,     priority: 100, survives_truncation: true)
      PERSISTENT = new(id: 1, name: :persistent, priority: 90,  survives_truncation: true)
      STRATEGIC  = new(id: 2, name: :strategic,  priority: 80,  survives_truncation: false)
      TACTICAL   = new(id: 3, name: :tactical,   priority: 70,  survives_truncation: false)
      HISTORY    = new(id: 4, name: :history,    priority: 50,  survives_truncation: false)
      TASK       = new(id: 5, name: :task,       priority: 100, survives_truncation: true)

      ALL = [SYSTEM, PERSISTENT, STRATEGIC, TACTICAL, HISTORY, TASK].freeze

      class << self
        def [](name) = ALL.find { |l| l.name == name }
        def by_priority = ALL.sort_by { |l| -l.priority }
        def truncatable = ALL.reject(&:survives_truncation)
      end
    end
  end
end
