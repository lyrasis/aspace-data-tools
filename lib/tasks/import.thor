# frozen_string_literal: true

class Import < Thor
  extend ADT::Command::Base

  desc "ead", "Create one EAD import_job background job per file in manifest"
  long_desc <<~DESC
    Input file is a CSV import manifest. Each row should describe an EAD
    file with these required columns:

     - filepath: path to EAD file (use absolute paths)
     - repo: database id of the repository the EAD will be imported into
  
    Note that the repo must be a numeric value, not a repository name.
    
    Rows with a missing file or unknown repo are skipped. The rest are
    submitted as separate import jobs, and the command waits for them to
    finish.
  DESC
  shared_option :input_file
  method_option :poll_interval,
    type: :numeric,
    default: 5,
    desc: "Seconds to wait between job status checks"
  method_option :timeout,
    type: :numeric,
    default: 600,
    desc: "Seconds to wait for jobs to finish before giving up; unfinished "\
      "jobs keep running in ArchivesSpace"
  def ead
    ADT::Import::Batch.new(
      input: options[:input_file],
      import_type: "ead_xml",
      poll_interval: options[:poll_interval],
      timeout: options[:timeout]
    ).call
  end
end
