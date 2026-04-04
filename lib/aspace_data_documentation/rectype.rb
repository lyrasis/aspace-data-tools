# frozen_string_literal: true

module AspaceDataDocumentation
  class Rectype
    attr_reader :name, :schema

    class << self
      # @param model [String] like "JSONModel(:agent_family) uri" or
      #   "JSONModel(:extent) object"
      def from_model_ref(model)
        namematch = model.match(/^JSONModel\(:(.*)\) /)
        unless namematch
          fail("#{name}: No jsonmodel_type name extracted from #{model}")
        end

        ADD.get_rectype(namematch[1])
      end
    end

    SIMPLE_TYPES = %w[string boolean date]
    COMPLEX_TYPES = %w[array]

    # @param name [String] of JSON model/record type
    # @param schema [Hash]
    def initialize(name, schema)
      @name = name
      @schema = schema
    end

    # @param mode [NilValue, :subrecord]
    def required_fields(mode = nil)
      fields = all_required.map do |k, v|
        type = v["type"]

        if k == "ref"
          k if v.key?("ifmissing")
        elsif simple_type?(type)
          k
        elsif objref?(v)
          "#{k} (ref)"
        elsif objref_array?(v)
          objref_required(k, v)
        elsif obj_or_ref?(v) || objs_or_refs?(v)
          obj_or_ref_requireds(k, v)
        elsif subrecord?(k, v)
          ADD::Rectype.from_model_ref(v.dig("items", "type"))
            .required_fields(:subrecord)
        else
          report_unknown(k, v)
        end
      end
      return fields.flatten.compact unless mode == :subrecord

      fields.flatten
        .map { |f| "#{name}/#{f}" }
    end

    private

    def all_required
      result = schema["properties"].select { |k, v| v["ifmissing"] == "error" }
      result.delete("jsonmodel_type")
      result
    end

    def simple_type?(str)
      return false unless str.is_a?(String)
      return true if SIMPLE_TYPES.include?(str)

      str.match?(/^JSONModel\(.* uri$/)
    end

    def subrecord?(k, v)
      return true if complex?(v) && model_items?(k, v)

      v["type"].match?(/^JSONModel\(.* object$/)
    end

    def complex?(v) = COMPLEX_TYPES.include?(v["type"])

    def model_items?(k, v)
      item_type = v.dig("items", "type")
      warn("#{name}/#{k}: No item type found in #{v}") unless item_type
      unless item_type.is_a?(String)
        warn("#{name}/#{k}: Non-String item type in #{v}")
      end
      unless item_type.end_with?(" object")
        warn("#{name}/#{k}: Non-object item type in #{v}")
      end

      item_type.start_with?("JSONModel")
    end

    def objref?(v) = v["type"] == "object" && v["subtype"] == "ref"

    def objref_array?(v)
      v["type"] == "array" &&
        v.dig("items", "type") == "object" &&
        v.dig("items", "subtype") == "ref"
    end

    def objref_required(k, v)
      ADD::Rectype.new(k, v["items"])
        .required_fields(:subrecord)
    end

    def obj_or_ref?(v) = v["type"].match?(/^JSONModel\(.* uri_or_object$/)

    def objs_or_refs?(v)
      v["type"] == "array" &&
        v.dig("items", "type")&.match?(/^JSONModel\(.* uri_or_object$/)
    end

    def obj_or_ref_requireds(k, v)
      from_obj = ADD::Rectype.from_model_ref(v.dig("items", "type"))
        .required_fields(:subrecord)
        .map { |f| "#{f} (if creating)" }

      from_obj + ["#{k}/ref (if referencing)"]
    end

    def report_unknown(k, v)
      warn("#{name}: Unknown type(s): #{k} (#{v["type"]})")
    end
  end
end
