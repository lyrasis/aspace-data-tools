# frozen_string_literal: true

require "forwardable"

module AspaceDataTools
  module Doc
    class Rectype
      extend Forwardable
      include DisplayNameable

      def_delegator :model, :nested_records

      attr_reader :name, :schema

      class << self
        # @param model [String] like "JSONModel(:agent_family) uri" or
        #   "JSONModel(:extent) object"
        def name_from_model_ref(model)
          namematch = model.match(/^JSONModel\(:(.*)\) /)
          unless namematch
            fail("#{name}: No jsonmodel_type name extracted from #{model}")
          end
          namematch[1]
        end
      end

      # @param name [String] of JSON model/record type
      # @param schema [Hash]
      def initialize(name, schema)
        @name = name
        @schema = schema
      end

      def model = ADT::AsCode::AsModel.for_rectype(name)

      def properties
        schema["properties"].map { |prop, cfg| Property.new(prop, cfg, self) }
      end

      def subrecords = @subrecords ||= build_subrecords

      def fields = @fields ||= build_fields

      def display_name = ADT::Doc.locales.dig(name, "_singular") ||
        fallback_display(name)

      def to_s
        "<##{self.class}:#{object_id.to_s(8)} name: #{name} !>"
      end
      alias_method :inspect, :to_s

      private

      def build_subrecords
        props = properties.select(&:subrecord?)
        return [] if props.empty?

        props.map { |prop| subrecs_by_pattern(prop) }.flatten
      end

      def subrecs_by_pattern(prop)
        if prop.simple_subrecord?
          ADT::Doc::Subrecord.new(prop, self)
        elsif prop.multi_subrecord?
          typeval = prop.config.dig("items", "type")
          ADT::Doc::Subrecord.new(prop, self, typeval)
        elsif prop.multi_multitype_subrecord?
          prop.config.dig("items", "type").map do |typehash|
            typeval = typehash["type"]
            ADT::Doc::Subrecord.new(prop, self, typeval)
          end
        end
      end

      def build_fields
        properties.select(&:field?)
          .map { |prop| Field.new(prop.name, prop.config, self) } +
          subrecord_fields
      end

      def subrecord_fields = subrecords.compact.map(&:fields).flatten
    end
  end
end
