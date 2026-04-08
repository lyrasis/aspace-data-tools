# frozen_string_literal: true

# Commands to produce data documentation
class Doc < Thor
  include ADT::Command::Base

  desc "required", "Print required fields to screen"
  def required
    ADT.reqfields
  end
end
