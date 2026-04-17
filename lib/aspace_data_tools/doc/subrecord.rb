# frozen_string_literal: true

module AspaceDataTools
  module Doc
    class Subrecord < Rectype
      include Parentable

      attr_reader :property, :parent, :modeltype, :depth

      # @param property [ADT::Doc::Property]
      # @param parent [ADT::Doc::Rectype, ADT::Doc::Subrecord]
      # @param modeltype [String]
      def initialize(property, parent, modeltype = nil)
        @property = property
        @parent = set_parent(parent)
        @modeltype = modeltype || extract_modeltype
        @depth = parent.is_a?(ADT::Doc::Rectype) ? 1 : parent.depth + 1
      end

      def name = property.name

      def config = property.config

      def modelname = @name ||= ADT::Doc::Rectype.name_from_model_ref(modeltype)

      def schema = @schema ||= ADT::Doc.get_rectype(modelname).schema

      def pattern = property.subrecord_pattern

      def required? = property.required?

      def display_name
        subrec_label_from_parent ||
          locales.dig(modelname, "_plural") ||
          fallback_display(property.name)
      end

      def to_s
        "<##{self.class}:#{object_id.to_s(8)} parent: #{parentstring}, "\
          "name: #{name}, depth: #{depth}, pattern: #{pattern} !>"
      end
      alias_method :inspect, :to_s

      private

      def extract_modeltype = property.config.dig("type")
    end
  end
end
