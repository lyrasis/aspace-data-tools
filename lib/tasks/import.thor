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

    Writes a report CSV with every manifest column plus job_id, job_status,
    status, record_created_uri, error_message, and log_path. Beside it are
    <report>_records.csv (every record each job created) and <report>_logs/
    (logs of jobs that did not succeed).
  DESC
  shared_option :input_file
  method_option :output,
    type: :string,
    aliases: "-o",
    desc: "Path of report CSV; defaults to <input>_report.csv"
  method_option :poll_interval,
    type: :numeric,
    default: 5,
    desc: "Seconds to wait between job status checks (5)"
  method_option :timeout,
    type: :numeric,
    default: 600,
    desc: "Seconds to wait for jobs to finish before giving up; unfinished "\
      "jobs keep running in ArchivesSpace (600)"
  def ead
    ADT::Import::Batch.new(
      input: options[:input_file],
      import_type: "ead_xml",
      poll_interval: options[:poll_interval],
      timeout: options[:timeout],
      output: options[:output]
    ).call
  end
end
