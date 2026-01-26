module Smolagents
  module Types
    module TypeSupport
      # Auto-generates to_h with support for calculated fields.
      #
      # Provides serialization to hash with all Data.define members plus
      # optional calculated fields that derive from the base members.
      #
      # @example Basic usage (all members)
      #   Point = Data.define(:x, :y) do
      #     include TypeSupport::Serializable
      #   end
      #
      #   Point.new(x: 1, y: 2).to_h
      #   # => { x: 1, y: 2 }
      #
      # @example With calculated fields
      #   TokenUsage = Data.define(:input_tokens, :output_tokens) do
      #     include TypeSupport::Serializable
      #     calculated_field :total_tokens, -> { input_tokens + output_tokens }
      #   end
      #
      #   TokenUsage.new(input_tokens: 100, output_tokens: 50).to_h
      #   # => { input_tokens: 100, output_tokens: 50, total_tokens: 150 }
      #
      # @example Multiple calculated fields
      #   Timing = Data.define(:start_time, :end_time) do
      #     include TypeSupport::Serializable
      #     calculated_field :duration, -> { end_time && (end_time - start_time) }
      #     calculated_field :running?, -> { end_time.nil? }
      #   end
      #
      module Serializable
        # Hook called when module is included.
        # Sets up calculated fields storage and defines to_h.
        #
        # @param base [Class] The Data.define class including this module
        def self.included(base)
          base.extend(ClassMethods)
          base.instance_variable_set(:@calculated_fields, {})

          members = base.members
          base.define_method(:to_h) do
            hash = members.to_h { |m| [m, public_send(m)] }
            self.class.calculated_fields.each do |name, proc|
              hash[name] = instance_exec(&proc)
            end
            hash
          end
        end

        # Class-level methods for defining calculated fields.
        module ClassMethods
          # Returns the calculated fields hash.
          #
          # @return [Hash{Symbol => Proc}] Field name to proc mapping
          def calculated_fields
            @calculated_fields ||= {}
          end

          # Defines a calculated field included in to_h output.
          #
          # @param name [Symbol] The field name
          # @param proc [Proc] Lambda computing the value (evaluated in instance context)
          # @return [void]
          #
          # @example
          #   calculated_field :total, -> { amount * quantity }
          def calculated_field(name, proc)
            @calculated_fields[name] = proc
          end
        end
      end
    end
  end
end
