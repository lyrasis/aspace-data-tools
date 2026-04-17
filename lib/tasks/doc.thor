# frozen_string_literal: true

require "csv"
require "table_tennis"

# Commands to produce data documentation
class Doc < Thor
  extend ADT::Command::Base

  desc "endpoints", "List all endpoints (schemas with uri property)"
  def endpoints = puts ADT::Doc.endpoints.keys

  desc "nonrec_endpoints", "List endpoints not considered top-level records"
  def nonrec_endpoints = puts ADT::Doc::Rectypes::NON_PRIMARY_RECTYPES.sort

  desc "schemas", "List all schemas"
  def schemas = puts ADT::Doc.schemas.keys

  desc "nested", "List ASModel classes with nested records. WARNING: INCOMPLETE"
  def nested
    ADT::Doc.rectypes.each do |rt|
      puts ""
      puts rt.name
      if rt.nested_records.empty?
        puts "No nested records"
      else
        pp(rt.nested_records)
      end
    end
  end

  # rubocop:disable Lint/Debugger
  desc "fields", "get info about ArchivesSpace fields"
  shared_option :command_mode
  shared_option :output_mode
  shared_option :output_path
  method_option :rectypes,
    desc: "Filter to specified record types, space-separated",
    required: false,
    type: :array,
    aliases: "-r"
  def fields
    rts = if options[:rectypes]
      options[:rectypes].map { |rt| ADT::Doc.get_rectype(rt) }
    else
      ADT::Doc.rectypes
    end

    f = rts.map(&:fields).flatten

    binding.pry if options[:command_mode] == "pry"

    if options[:output_mode] == "stdout"
      puts TableTennis.new(f.map(&:to_row))
    elsif options[:output_mode] == "csv"
      f.map!(&:to_row)

      path = if options[:output_path]
        File.expand_path(options[:output_path])
      else
        File.join(Bundler.root, "doc", "fields.csv")
      end

      CSV.open(path, "w", headers: f[0].keys, write_headers: true) do |csv|
        f.each { |f| csv << f.values }
      end

      puts "Output written to #{path}"
    end
    # rubocop:enable Lint/Debugger
  end
end
