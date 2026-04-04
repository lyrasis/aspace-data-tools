# frozen_string_literal: true

require "json"

module AspaceDataDocumentation
  class Config
    # @param path [NilValue, String] location of config .json file
    def initialize(path = nil)
      @path = path || get_default_path
    end

    def call
      parse.each { |key, val| define(key, val) }
      self
    end

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
        File.join("~", ".config", "aspace_data_documentation", "config.json")
      )
    end

    def parse
      @parse ||= JSON.parse(File.read(path), symbolize_names: true)
    end

    def define(key, val)
      self.class.define_method(key) { val }
    end
  end
end
