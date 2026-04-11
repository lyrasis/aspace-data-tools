# frozen_string_literal: true

class Rectypes < Thor
  extend ADT::Command::Base

  desc "all", "List all top-level record types"
  def all
    puts ADT::Doc.rectypes.map(&:name)
  end
end
