# frozen_string_literal: true

class Config < Thor
  include ADT::Command::Base

  desc "show", "Print config to screen"
  def show
    pp ADT.config.to_h
  end
end
