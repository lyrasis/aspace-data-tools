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

    # @param name [String] jsonmodel_type of record
    def get_rectype(name)
      fetched = rectypes.find { |rt| rt.name == name }
      return fetched if fetched

      result = ADT.client.get("/schemas/#{name}")
      return ADT::Rectype.new(name, result.parsed) if result.status_code == 200

      fail("#{result.status}\n#{result.parsed}")
    end

    def rectypes
      @rectypes ||= Rectypes.new.call
    end

    def reqfields
      ADT.rectypes.each do |rt|
        puts "#{rt.name}:\n#{rt.required_fields.join(",")}\n\n"
      end
      nil
    end

    def locales_file = File.join(Bundler.root, "vendor", "locales.yml")
  end
end

ADT.loader
