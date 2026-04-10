# frozen_string_literal: true

# Commands to produce data documentation
class Doc < Thor
  include ADT::Command::Base

  desc "required", "Print required fields to screen"
  def required
    ADT.reqfields
  end

  desc "update_locales", "Download current locales file"
  method_option :force,
    required: false,
    type: :boolean,
    desc: "Download if file exists and was already updated today?",
    aliases: "-f"
  def update_locales
    res = if options.key?(:force)
      ADT::Doc::UpdateLocales.new(force: options[:force]).call
    else
      ADT::Doc::UpdateLocales.new.call
    end
    puts res
  end
end
