# frozen_string_literal: true

module AspaceDataTools
  module Doc
    class Rectypes
      NON_PRIMARY_RECTYPES = %w[name_form enumeration_value enumeration
        enumeration_migration merge_request merge_request_detail
        oai_config permission repository
        assessment_attribute_definitions classification_tree
        custom_report_template default_values digital_object_tree
        group job preference rde_template required_fields
        resource_ordered_records resource_tree
        repository_with_agent telephone active_edits user
        vocabulary]

      def initialize
      end

      def call
        ADT::Doc.endpoints
          .except(*NON_PRIMARY_RECTYPES)
          .map { |name, schema| Rectype.new(name, schema) }
      end
    end
  end
end
