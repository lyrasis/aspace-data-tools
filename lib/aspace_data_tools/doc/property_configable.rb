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

      def config_includes_model?
        config.to_s
          .match?(/JSONModel\(:[^)]+\)/)
      end

      def subrecord?
        return false if read_only?

        config.to_s
          .match?(/JSONModel\(:[^)]+\) object"/)
      end

      def true_val?(val) = val == true || val == "true"
    end
  end
end
