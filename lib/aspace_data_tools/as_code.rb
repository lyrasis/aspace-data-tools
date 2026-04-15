# frozen_string_literal: true

require "prism"

module AspaceDataTools
  module AsCode
    module_function

    def model_path = File.join(ADT.config.aspace_code_path, "backend", "app",
      "model")

    def model_files = Dir.glob("*.rb", base: model_path)
      .map { |fn| File.join(model_path, fn) }

    def models = @models ||= get_models

    def get_models
    end
    private_class_method :get_models
  end
end
