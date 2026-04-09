# frozen_string_literal: true

require "pry"
require "thor"
require "zeitwerk"

# Main namespace
module AspaceDataTools
  ::ADT = AspaceDataTools

  class << self
    def loader
      @loader ||= setup_loader
    end

    private def setup_loader
      @loader = Zeitwerk::Loader.for_gem
      @loader.ignore("#{__dir__}/tasks")
      @loader.enable_reloading
      @loader.setup
      @loader
    end

    def reload!
      @loader.reload
    end

    def config
      @config ||= Config.new.call
    end

    def client
      @client ||= Asclient.new.call
    end

    def locales_file = File.join(Bundler.root, "vendor", "locales.yml")
  end
end

ADT.loader
