# frozen_string_literal: true

module AspaceDataTools
  module Doc
    class Field
      include DisplayNameable
      include Parentable
      include PropertyConfigable

      attr_reader :name, :config, :parent

      # @param name [String]
      # @param config [Hash]
      # @param parent [ADT::Doc::Rectype, ADT::Doc::Subrecord]
      def initialize(name, config, parent)
        @name = name
        @config = config
        @parent = set_parent(parent)
      end

      def type = config["type"]

      def rectype = parent.first

      def subrecords = parent[1..]

      def display_name
        field_label_from_subrec unless subrecords.empty?

        field_label_from_rt
      end

      def to_row
        # binding.pry unless subrecords.empty?
        {
          record_type: rectype.name,
          record_type_display_name: rectype.display_name,
          subrecords: subrecords.map(&:name).join("/"),
          subrecord_display_names: subrecords.map(&:display_name).join("/"),
          field: name,
          field_display_name: display_name,
          required: determine_required
        }
      end

      def to_s
        "<##{self.class}:#{object_id.to_s(8)} "\
          "parent: #{parentstring}, name: #{name} !>"
      end
      alias_method :inspect, :to_s

      private

      def field_label_from_rt
        locales.dig(rectype.name, name) || fallback_display(name)
      end

      def field_label_from_subrec
        locales.dig(subrecords.last.modelname, name) ||
          fallback_display(name)
      end

      def determine_required
        return "y" if top_rec_required?
        return "y (in required subrecord)" if required_subrec_required?
        return "if optional subrecord populated" if required_by_subrec?

        "n"
      end

      def top_rec_required? = subrecords.empty? && required?

      def required_subrec_required? = subrecords.all?(&:required?) && required?

      def required_by_subrec? = !subrecords.last&.required? && required?
    end
  end
end
