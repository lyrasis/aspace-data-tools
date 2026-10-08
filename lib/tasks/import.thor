# frozen_string_literal: true

class Import < Thor
  extend ADT::Command::Base

  desc "ead", "Create one EAD import_job background job per file in manifest"
  long_desc <<~DESC
    Input file is a CSV import manifest. Each row should describe an EAD
    file with these required columns:

     - filepath: path to EAD file (use absolute paths)
     - repo: database id of the repository the EAD will be imported into

    Rows with a missing file or unknown repo are skipped. The rest are
    submitted as separate import jobs.
  DESC
  shared_option :input_file
  def ead
    ADT::Import::Batch.new(
      input: options[:input_file],
      import_type: "ead_xml"
    ).call
  end
end
