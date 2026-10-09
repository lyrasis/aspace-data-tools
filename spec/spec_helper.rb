# frozen_string_literal: true

require "bundler/setup"
require_relative "../lib/aspace_data_tools"

Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

module FixtureHelpers
  def fixture_path(*parts)
    File.join(__dir__, "support", "fixtures", *parts)
  end
end

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.include FixtureHelpers
end
