# frozen_string_literal: true

class Create < Thor
  extend ADT::Command::Base

  desc "resources", "Create a new repository in target ArchivesSpace instance"
  shared_option :input_file
  method_option :repo,
    required: false,
    type: :numeric,
    desc: "repo_id into which resources will be ingested",
    aliases: "-r"
  method_option :stop_after,
    required: false,
    type: :string,
    enum: %w[map post],
    desc: "",
    aliases: "-s"
  def resources
    opts = {
      input: options[:input_file]
    }
    opts[:repo] = options[:repo] if options.key?(:repo)
    if options.key?(:stop_after)
      opts[:mode] = options[:stop_after].to_sym
    end
    ADT::Create::Resources.new(**opts).call
  end
end
