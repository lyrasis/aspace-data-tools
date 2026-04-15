# frozen_string_literal: true

# Commands to produce data documentation
class Doc < Thor
  extend ADT::Command::Base

  desc "endpoints", "List all endpoints (schemas with uri property)"
  def endpoints = puts ADT::Doc.endpoints.keys

  desc "nonrec_endpoints", "List endpoints not considered top-level records"
  def nonrec_endpoints = puts ADT::Doc::Rectypes::NON_PRIMARY_RECTYPES.sort

  desc "schemas", "List all schemas"
  def schemas = puts ADT::Doc.schemas.keys

  desc "nested", "List ASModel classes with nested records"
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

  desc "required", "Print required fields to screen"
  def required
    ADT.reqfields
  end
end
