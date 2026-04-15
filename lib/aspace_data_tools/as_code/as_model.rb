# frozen_string_literal: true

module AspaceDataTools
  module AsCode
    class AsModel
      include NestedRecordable

      def self.for_rectype(rectype)
        path = ADT::AsCode.model_files
          .find { |f| File.basename(f) == "#{rectype}.rb" }
        new(path)
      end

      def initialize(path)
        @path = path
        @src = File.read(path)
      end

      def parsed
        @parsed ||= Prism.parse(src).value
      end

      private

      attr_reader :path, :src
    end
  end
end
