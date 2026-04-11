# frozen_string_literal: true

# Commands to get field-level info
class Properties < Thor
  extend ADT::Command::Base

  # rubocop:disable Lint/Debugger
  desc "norm", "Print normalized field config to screen"
  shared_option :command_mode
  method_option :filter,
    required: false,
    type: :string,
    enum: %w[model subrec],
    aliases: "-f"
  def norm
    props = ADT::Doc.properties

    case options[:filter]
    when "model"
      props.select!(&:config_includes_model?)
    when "subrec"
      props.select!(&:subrecord?)
    end

    results = props.map(&:normalize_config)
      .uniq
      .sort_by { |h| h.to_s }

    if options[:command_mode] == "stdout"
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

  desc "readonly", "List read only properties"
  def readonly = puts pp(ADT::Doc.properties.select(&:read_only?))
end
