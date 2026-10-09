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
      # TODO: use this to restrict ingests to supported formats (done) and to 
      # note the pattern that will go in record_created_uri (TK) 
      IMPORT_TYPES = {
        "ead_xml" => {primary: %r{/resources/\d+\z}}
      }.freeze

      # @param input [String] path to manifest CSV
      # @param import_type [String] key of IMPORT_TYPES, above
      # @param poll_interval [Numeric] seconds between job status checks
      # @param timeout [Numeric] seconds to wait for jobs to finish
      def initialize(input:, import_type:, poll_interval: 5, timeout: 3600)
        unless IMPORT_TYPES.key?(import_type)
          fail("‼️ Unsupported import type: #{import_type}")
        end

        @input = input
        @import_type = import_type
        @poll_interval = poll_interval
        @timeout = timeout
        @client = ADT.client
      end

      def call
        jobs = Manifest.new(path: input, repo_ids: list_repo_ids).jobs
        submit_all(jobs)
        wait_for(jobs)
        summarize(jobs)
        jobs
      end

      private

      attr_reader :input, :import_type, :poll_interval, :timeout, :client

      def wait_for(jobs)
        submitted = jobs.select { |job| job.status == :submitted }
        return if submitted.empty?

        puts "Waiting for #{submitted.length} import jobs to finish"
        Poller.new(client: client, interval: poll_interval, timeout: timeout)
          .call(submitted)
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
        puts "Submitted #{import_type} import jobs from #{input}"

        %i[submitted timeout failed skipped].each do |status|
          puts "  - #{counts.fetch(status, 0)} #{status}"
        end
        puts TableTennis.new(jobs.map { |job| summary_row(job) })
      end

      def summary_row(job)
        {
          file: job.filepath && File.basename(job.filepath),
          repo: job.repo,
          job_id: job.job_id,
          status: job.status,
          job_status: job.job_status,
          message: job.message
        }
      end
    end
  end
end
