# frozen_string_literal: true

require "psych"

module AspaceDataTools
  module Doc
    module_function

    def locales = @locales ||= get_locales
    def get_locales
      result = ADT::Doc::UpdateLocales.new.call
      return {} if result == :failure

      Psych.load_file(ADT.locales_file, aliases: true)["en"]
    end
    private_class_method(:get_locales)
  end
end
