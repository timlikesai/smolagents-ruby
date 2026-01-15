module Smolagents
  module Security
    # Helper methods for extracting information from Ruby AST (S-expressions).
    module AstHelpers
      IDENTIFIER_TYPES = %i[@ident @const].freeze

      module_function

      def extract_method_name(sexp)
        sexp.find { |elem| elem.is_a?(Array) && IDENTIFIER_TYPES.include?(elem[0]) }&.[](1)
      end

      def extract_const_path(sexp)
        parts = []
        extract_const_path_parts(sexp, parts)
        parts.join("::") unless parts.empty?
      end

      def extract_const_path_parts(sexp, parts)
        return unless sexp.is_a?(Array)

        parts << sexp[1] if sexp[0] == :@const
        return unless %i[const_path_ref].include?(sexp[0]) || !%i[@const].include?(sexp[0])

        sexp.each { |child| extract_const_path_parts(child, parts) }
      end
    end
  end
end
