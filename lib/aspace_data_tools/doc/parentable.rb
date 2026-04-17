# frozen_string_literal: true

module AspaceDataTools
  module Doc
    module Parentable
      def parentstring = parent.map(&:name).join("/")

      private

      def set_parent(parent)
        return [parent] unless parent.respond_to?(:parent)

        [parent.parent, parent].flatten
      end
    end
  end
end
