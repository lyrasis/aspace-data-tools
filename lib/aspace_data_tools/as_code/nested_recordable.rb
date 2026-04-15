# frozen_string_literal: true

module AspaceDataTools
  module AsCode
    module NestedRecordable
      def nested_records = @nested_records ||= build_nested_records

      private

      def build_nested_records
        defs = parsed.accept(DefNestedRecord.new)
        return [] if defs.empty?

        defs.map { |node| build_nested_record_def(node) }
      end

      def build_nested_record_def(node)
        err = "Cannot build nested record def from code at #{path} "\
          "#{node.location}:\n#{node.slice_lines}\nREASON: "
        args = node.arguments
        unless args.type == :arguments_node
          fail("#{err}Level 1 is not :arguments_node")
        end

        nextargs = args.arguments
        unless nextargs.length == 1
          fail("#{err}Level 2 has more than one element")
        end

        h = nextargs[0]
        unless h.type == :keyword_hash_node
          fail("#{err}Level 2 is not :keyword_hash_node")
        end

        h.elements.map do |assocnode|
          keep = %w[the_property contains_records_of_type]
          key = assocnode.key.unescaped
          next unless keep.include?(key)

          [key, assocnode.value.unescaped]
        end.compact.to_h
      end
    end
  end
end
