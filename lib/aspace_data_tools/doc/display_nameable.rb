# frozen_string_literal: true

module AspaceDataTools
  module Doc
    module DisplayNameable
      def locales = ADT::Doc.locales

      def fallback_display(str) = str.split("_")
        .map(&:capitalize)
        .join(" ")

      def subrec_label_from_parent
        r = locales.dig(parent.first.name, property.name)
        return unless r.is_a?(String)

        r
      end
    end
  end
end
