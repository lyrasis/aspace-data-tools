# frozen_string_literal: true

# Commands to get field-level info
class Properties < Thor
  extend ADT::Command::Base

  # rubocop:disable Lint/Debugger
  desc "get", "Retrieve matching property"
  shared_option :command_mode
  method_option :name,
    required: true,
    type: :string,
    aliases: "-n"
  method_option :rectype,
    required: false,
    type: :string,
    aliases: "-r"
  def get
    props = ADT::Doc.properties
      .select { |prop| prop.name == options[:name] }

    if options[:rectype]
      props = props.select { |prop| prop.rectype == options[:rectype] }
    end

    props.each_with_index { |prop, idx| puts "#{idx}\n#{prop}" }
    binding.pry if options[:command_mode] == "pry"
  end

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

    results.each_with_index { |r, idx| puts "#{idx}\n#{r}" }
    puts("\nCount: #{results.length}")

    binding.pry if options[:command_mode] == "pry"
  end

  # rubocop:enable Lint/Debugger

  desc "readonly", "List read only properties"
  def readonly = puts pp(ADT::Doc.properties.select(&:read_only?))
end
