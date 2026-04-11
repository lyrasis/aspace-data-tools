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

      def read_only? = config.dig("readonly") == true

      def config_includes_model?
        config.to_s
          .match?(/JSONModel\(:[^)]+\)/)
      end

      def subrecord?
        return false if read_only?

        config.to_s
          .match?(/JSONModel\(:[^)]+\) object"/)
      end
    end
  end
end
