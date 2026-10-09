# frozen_string_literal: true

require "json"
require "table_tennis"

module AspaceDataTools
  module Import
    # Submits one ArchivesSpace import_job per manifest row, so that each file
    # succeeds or fails on its own and can target its own repository, as opposed
    # to uploading via the GUI into a single repository. 
    class Batch
      # Supported import_job import_type values. :primary matches the uri of
      # the main record each file is expected to create.
      #
      # Used to restrict ingests to supported formats, and by Results to pick
      # the record that goes in record_created_uri.
      IMPORT_TYPES = {
        "ead_xml" => {primary: %r{/resources/\d+\z}}
      }.freeze

      # Order in which statuses are listed in the end-of-run summary
      STATUS_ORDER = %i[success no_record import_failed unresolved timeout
        submitted failed skipped].freeze

      # @param input [String] path to manifest CSV
      # @param import_type [String] key of IMPORT_TYPES, above
      # @param poll_interval [Numeric] seconds between job status checks
      # @param timeout [Numeric] seconds to wait for jobs to finish
      # @param output [String, nil] path of report CSV; defaults to
      #   <input>_report.csv. Created record uris and job logs are written
      #   beside it.
      def initialize(input:, import_type:, poll_interval: 5, timeout: 600,
        output: nil)
        unless IMPORT_TYPES.key?(import_type)
          fail("‼️ Unsupported import type: #{import_type}")
        end

        @input = File.expand_path(input)
        @import_type = import_type
        @poll_interval = poll_interval
        @timeout = timeout
        @output = File.expand_path(
          output || @input.sub(/(\.csv)?\z/i, "_report.csv")
        )
        @client = ADT.client
      end

      def call
        # Straight line of logic: load the manifest, extract data
        # from it and map the data to jobs, submit the jobs, and 
        # report on them once they've finished.
        manifest = Manifest.new(path: input, repo_ids: list_repo_ids)
        jobs = manifest.jobs
        submit_all(jobs)
        finished = wait_for(jobs)
        collect_results(finished)
        finish(manifest, jobs)
      rescue Interrupt
        # Submitted jobs keep running in ArchivesSpace, so save their job ids
        # before exiting.
        raise unless jobs

        puts "\nInterrupted; writing report of progress so far"
        finish(manifest, jobs)
        # i.e. SIGINT (no named constant in Ruby?)
        exit 130
      end

      private

      attr_reader :input, :import_type, :poll_interval, :timeout, :output,
        :client

      def finish(manifest, jobs)
        Report.new(path: output, headers: manifest.headers, jobs: jobs).call
        summarize(jobs)
        jobs
      end

      # @return [Array<Job>] jobs that finished
      def wait_for(jobs)
        submitted = jobs.select { |job| job.status == :submitted }
        return [] if submitted.empty?

        puts "Waiting for #{submitted.length} import jobs to finish"
        Poller.new(client: client, interval: poll_interval, timeout: timeout)
          .call(submitted)
      end

      def collect_results(finished)
        return if finished.empty?

        puts "Collecting results for #{finished.length} finished jobs"
        Results.new(
          client: client,
          primary: IMPORT_TYPES[import_type][:primary],
          log_dir: output.sub(/(\.csv)?\z/i, "_logs")
        ).call(finished)
      end

      # Generate list of available repos in this instance 
      def list_repo_ids
        client.all("repositories").map { |repo| repo["uri"].split("/").last }
      end

      # Submit the batch jobs by iterating over the list of pending
      # imports and calling submit() on each 
      def submit_all(jobs)
        pending = jobs.select(&:pending?)
        pending.each.with_index(1) do |job, idx|
          submit(job)
          puts "  #{idx}/#{pending.length} #{File.basename(job.filepath)}: "\
            "#{job.job_id ? "job #{job.job_id}" : job.message}"
        end
      end

      # Read the file to import, call the post_multipart() function
      # in the client to submit it. If status != 200, set the job
      # status to failed, ideally with any kind of error message.
      def submit(job)
        response = File.open(job.filepath) do |file|
          client.post_multipart(
            "repositories/#{job.repo}/jobs_with_files",
            {job: job_payload(job).to_json, files: [file]}
          )
        end
        return submitted(job, response) if response.status_code == 200

        job.status = :failed
        job.message = error_message(response)
      rescue => err
        job.status = :failed
        job.message = "#{err.class}: #{err.message}"
      end

      # Convenience function to format the payload. import_type is only 
      # ead_xml at the moment, but should be something in IMPORT_TYPES.
      def job_payload(job)
        {
          jsonmodel_type: "job",
          job: {
            jsonmodel_type: "import_job",
            import_type: import_type,
            filenames: [File.basename(job.filepath)]
          }
        }
      end

      def submitted(job, response)
        job.job_id = response.parsed["id"]
        job.status = :submitted
      end

      def error_message(response)
        parsed = response.parsed
        detail = if parsed.is_a?(Hash) && parsed.key?("error")
          err = parsed["error"]
          err.is_a?(String) ? err : err.to_json
        else
          response.body.to_s.strip
        end
        "HTTP #{response.status_code}: #{detail}"
      end

      def summarize(jobs)
        counts = jobs.group_by(&:status).transform_values(&:length)
        puts "#{import_type} import results for #{input}"

        STATUS_ORDER.each do |status|
          next unless counts.key?(status)

          puts "  - #{counts[status]} #{status}"
        end
        puts TableTennis.new(jobs.map { |job| summary_row(job) })
      end

      def summary_row(job)
        {
          file: job.filepath && File.basename(job.filepath),
          repo: job.repo,
          job_id: job.job_id,
          status: job.status,
          record: job.record_created_uri,
          message: job.message
        }
      end
    end
  end
end
