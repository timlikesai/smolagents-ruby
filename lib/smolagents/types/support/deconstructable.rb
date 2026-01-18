module Smolagents
  module Types
    module TypeSupport
      # Auto-generates deconstruct_keys from Data.define members.
      #
      # Pattern matching in Ruby requires `deconstruct_keys` to return a hash
      # of the object's members. This module eliminates the boilerplate by
      # generating the method automatically from the Data.define members.
      #
      # @example Basic usage
      #   TokenUsage = Data.define(:input_tokens, :output_tokens) do
      #     include TypeSupport::Deconstructable
      #   end
      #
      #   usage = TokenUsage.new(input_tokens: 100, output_tokens: 50)
      #   case usage
      #   in TokenUsage[input_tokens:, output_tokens:]
      #     puts "#{input_tokens} in, #{output_tokens} out"
      #   end
      #
      # @example With filtered keys
      #   case result
      #   in { state:, output: } if state == :success
      #     handle_success(output)
      #   end
      #
      module Deconstructable
        # Hook called when module is included.
        # Defines deconstruct_keys based on the class members.
        #
        # @param base [Class] The Data.define class including this module
        def self.included(base)
          return unless base.respond_to?(:members)

          members = base.members
          base.define_method(:deconstruct_keys) do |keys|
            if keys.nil?
              members.to_h { |m| [m, public_send(m)] }
            else
              (keys & members).to_h { |m| [m, public_send(m)] }
            end
          end
        end
      end
    end
  end
end
