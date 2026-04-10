# frozen_string_literal: true

# Commands to get field-level info
class Fields < Thor
  include ADT::Command::Base

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
end
