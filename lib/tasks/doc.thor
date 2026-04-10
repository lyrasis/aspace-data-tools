# frozen_string_literal: true

# Commands to produce data documentation
class Doc < Thor
  include ADT::Command::Base

  desc "required", "Print required fields to screen"
  def required
    ADT.reqfields
  end

  # rubocop:disable Lint/Debugger
  desc "norm", "Print normalized field config to screen"
  method_option :mode,
    required: false,
    default: "stdout",
    type: :string,
    enum: %w[stdout pry],
    aliases: "-m"
  def norm
    results = ADT::Doc.rectypes
      .map(&:norm)
      .flatten
      .uniq
      .sort_by { |h| h.to_s }

    if options[:mode] == "stdout"
      results.each do |r|
        pp(r)
        puts ""
      end
      puts("\nCount: #{results.length}")
    else
      puts("\nCount: #{results.length}")
      binding.pry
    end
  end
  # rubocop:enable Lint/Debugger

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
