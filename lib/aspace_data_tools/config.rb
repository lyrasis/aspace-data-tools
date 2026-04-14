# frozen_string_literal: true

require "json"

module AspaceDataTools
  class Config
    # @param path [NilValue, String] location of config .json file
    def initialize(path = nil)
      @path = path || get_default_path
    end

    def call
      parse.each { |key, val| define(key, val) }
      self
    end

    def aspace_code_path = File.expand_path(parse[:aspace_code_path])

    def to_h
      parse
    end

    private

    attr_reader :path

    def get_default_path
      return preferred_path if File.exist?(preferred_path)

      File.join(Bundler.root, "sample_config.json")
    end

    def preferred_path
      File.expand_path(
        File.join("~", ".config", "aspace-data-tools", "config.json")
      )
    end

    def parse
      @parse ||= JSON.parse(File.read(path), symbolize_names: true)
    end

    def define(key, val)
      return if self.class.method_defined?(key)

      self.class.define_method(key) { val }
    end
  end
end
