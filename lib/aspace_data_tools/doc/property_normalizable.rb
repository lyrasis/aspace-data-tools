# frozen_string_literal: true

module AspaceDataTools
  module Doc
    # Mixin module to handle normalization of field config
    module PropertyNormalizable
      def normalize_config(h = config)
        h.map { |k, v| normalize(k, v) }.to_h
      end

      private

      def normalize(k, v)
        return [k, v] if k == "type" &&
          v.is_a?(String) &&
          !v.start_with?("JSONModel(:")
        return [k, v] if k == "type" &&
          v.is_a?(Array) &&
          v.all? { |ve| ve.is_a?(String) && !ve.start_with?("JSONModel") }
        return [k, v] if k == "tags"

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
        elsif v.is_a?(Array) && v.all? { |e| e.is_a?(Hash) }
          [k, v.map { |ve| normalize_config(ve) }.uniq]
        elsif v.is_a?(Array) &&
            v.all? { |e| e.is_a?(String) && e.start_with?("JSONModel") }
          [k, ["JSONModel(:rectype)"]]
        else
          fail("Unhandled field config pattern in #{rectype.name}:\n"\
               "KEY: #{k}\nVALUE: #{pp(v)}")
        end
      end
    end
  end
end
