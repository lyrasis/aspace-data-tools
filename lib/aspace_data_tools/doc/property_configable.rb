# frozen_string_literal: true

module AspaceDataTools
  module Doc
    # Mixin module for determining field type and other information from
    #   schema properties hash values
    module PropertyConfigable
      SIMPLE_TYPES = %w[string boolean date]

      def category
        return :subrecord if subrecord?

        :field
      end

      def read_only? = true_val?(config.dig("readonly"))

      def required? = config.dig("ifmissing") == "error"

      def config_includes_model?
        config.to_s
          .match?(/JSONModel\(:[^)]+\)/)
      end

      def field?
        return false if name.start_with?("_")
        return false if %w[jsonmodel_type lock_version uri].include?(name)
        return false if read_only?

        !subrecord?
      end

      def subrecord?
        return false if read_only?

        config.to_s
          .match?(/JSONModel\(:[^)]+\) object"/)
      end

      # Normalized config looks like:
      #   {"type" => "JSONModel(:rectype) object"}
      def simple_subrecord?
        return unless subrecord?

        type = config.dig("type")
        return unless type
        return unless type.is_a?(String)

        model?(type)
      end

      def multi_subrecord?
        return unless subrecord?

        type = config.dig("type")
        return unless type == "array"

        items = config.dig("items")
        return unless items.is_a?(Hash) &&
          items.keys == ["type"] &&
          items["type"].is_a?(String)

        model?(items["type"])
      end

      def multi_multitype_subrecord?
        return unless subrecord?

        type = config.dig("type")
        return unless type == "array"

        items = config.dig("items")
        return unless items.is_a?(Hash) &&
          items.keys == ["type"] &&
          items["type"].is_a?(Array)

        items["type"].all? do |itemtype|
          itemtype.is_a?(Hash) &&
            itemtype.keys == ["type"] &&
            model?(itemtype["type"])
        end
      end

      def subrecord_pattern
        if simple_subrecord?
          :simple
        elsif multi_subrecord?
          :multi
        elsif multi_multitype_subrecord?
          :multi_multitype
        end
      end

      def model?(str) = str.start_with?("JSONModel(")

      def true_val?(val) = val == true || val == "true"
    end
  end
end
