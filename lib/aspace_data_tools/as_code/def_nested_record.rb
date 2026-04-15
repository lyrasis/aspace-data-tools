# frozen_string_literal: true

module AspaceDataTools
  module AsCode
    class DefNestedRecord < Prism::Visitor
      attr_reader :defs

      def initialize
        @defs = []
      end

      def visit_call_node(node)
        defs << node if node.name == :def_nested_record
      end

      def visit_program_node(node)
        super
        defs
      end
    end
  end
end
