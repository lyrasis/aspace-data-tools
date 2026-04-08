# frozen_string_literal: true

class Repo < Thor
  include ADT::Command::Base

  desc "create", "Create a new repository in target ArchivesSpace instance"
  method_option :repo_code,
    required: true,
    type: :string,
    desc: "repo_code value for new respository",
    aliases: "-c"
  method_option :name,
    required: false,
    type: :string,
    desc: "name value for new repository, IN QUOTES; defaults to upcased "\
    "repo_code if not provided",
    aliases: "-n"
  method_option :agent_contact_name,
    required: false,
    type: :string,
    desc: "agent contact for new repository, IN QUOTES; defaults to upcased "\
    "repo_code if not provided",
    aliases: "-a"
  def create
    ADT::Repo::Creator.new(options).call
  end

  desc "list", "List existing repos in ArchivesSpace instance"
  def list
    ADT::Repo::Lister.new.call
  end
end
