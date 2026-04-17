# frozen_string_literal: true

module AspaceDataTools
  module Doc
    # Mixin module to handle normalization of field config
    module PropertyNormalizable
      include PropertyConfigable

      def normalize_config(h = config)
        h.map { |k, v| normalize(k, v) }.compact.to_h
      end

      private

      def normalize(k, v)
        return [k, v] if k == "type" &&
          v.is_a?(String) &&
          !model?(v)
        return [k, v] if k == "type" &&
          v.is_a?(Array) &&
          v.all? { |ve| ve.is_a?(String) && !model?(ve) }
        if v.is_a?(Array) &&
            v.all? { |e| e.is_a?(Hash) && type_hash?(e) }
          return [k, [{"type" => "JSONModel(:rectype)"}]]
        end
        return if k == "tags"

        if k == "dynamic_enum"
          [k, "enum_name"]
        elsif k == "maxLength"
          [k, 100]
        elsif k == "enum"
          [k, [:enumvals]]
        elsif k == "type" && v.is_a?(String)
          [k, v.sub(/\(:[^)]+\)/, "(:rectype)")]
        elsif k != "type" && !v.respond_to?(:each)
          [k, v]
        elsif v.is_a?(Hash)
          [k, normalize_config(v)]
        elsif v.is_a?(Array) &&
            v.all? { |e| e.is_a?(String) && model?(e) }
          [k, ["JSONModel(:rectype)x#{v.length}"]]
        else
          fail("Unhandled field config pattern in #{rectype.name}:\n"\
               "KEY: #{k}\nVALUE: #{pp(v)}")
        end
      end

      def type_hash?(h) = h.keys == ["type"]
    end
  end
end
