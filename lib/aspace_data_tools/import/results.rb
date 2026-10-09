# frozen_string_literal: true

require "fileutils"

module AspaceDataTools
  module Import
    # Works out what each finished import job actually did: collects the
    # uris of all records it created, picks out the primary record, and
    # sets the job's final status. For jobs that did not succeed, saves
    # the job log and pulls an error message out of it so that we have
    # at least some sense of what happened at a glance
    class Results
      # ArchivesSpace's maximum page size--can't change this, per docs
      PAGE_SIZE = 250
      # From backend/app/lib/streaming_import.rb in aspace. I don't think
      # there's a straightforward way to confirm that this has happened 
      # (i.e. there were no records) aside from matching the string,
      # but flagging this as an approach that feels a little fragile. 
      NO_RECORDS = "No records were found in the input file!"

      # @param client [ArchivesSpace::Client]
      # @param primary [Regexp] matches the uri of the main record each file
      #   is expected to create (see Batch::IMPORT_TYPES)
      # @param log_dir [String] directory to write logs of unsuccessful jobs
      def initialize(client:, primary:, log_dir:)
        @client = client
        @primary = primary
        @log_dir = log_dir
      end

      # @param jobs [Array<Job>] finished jobs (see Poller)
      def call(jobs)
        jobs.each.with_index(1) do |job, idx|
          resolve(job)
          puts "  #{idx}/#{jobs.length} job #{job.job_id}: #{job.status}"
        end
      end

      private

      attr_reader :client, :primary, :log_dir

      def resolve(job)
        job.record_uris = fetch_record_uris(job)
        job.status = status_for(job)
        save_log(job) unless job.status == :success
      rescue => err
        job.status = :unresolved
        job.message = "could not retrieve results: #{err.class}: "\
          "#{err.message}"
      end

      def status_for(job)
        return :import_failed unless job.job_status == "completed"

        primaries = job.record_uris.grep(primary)
        return :no_record if primaries.empty?

        job.record_created_uri = primaries.first
        if primaries.length > 1
          job.message = "multiple primary records created: "\
            "#{primaries.join(" ")}"
        end
        :success
      end

      # Pages through the job's created records. Stops at the last_page
      # reported by ArchivesSpace rather than requesting pages until one
      # comes back empty.
      def fetch_record_uris(job)
        path = "repositories/#{job.repo}/jobs/#{job.job_id}/records"
        uris = []
        page = 1
        loop do
          parsed = get!(path, query: {page: page, page_size: PAGE_SIZE})
          uris.concat(parsed["results"].map { |r| r.dig("record", "ref") })
          break if page >= parsed["last_page"].to_i

          page += 1
        end
        uris.compact
      end

      def save_log(job)
        log = fetch_log(job)
        FileUtils.mkdir_p(log_dir)
        job.log_path = File.join(log_dir, log_filename(job))
        File.write(job.log_path, log)
        job.message = error_line(log)
      end

      # The log endpoint returns plain text, so this uses body, not parsed
      def fetch_log(job)
        response = client.get(
          "repositories/#{job.repo}/jobs/#{job.job_id}/log"
        )
        check!(response)
        response.body.to_s
      end

      def log_filename(job)
        "#{job.job_id}_#{File.basename(job.filepath, ".*")}.log"
      end

      # The final log line is usually a progress line like
      # "6. DONE: Cleaning up", so skip those and the header, and prefer
      # the known no-records message or a line mentioning an error. See
      # note above re: NO_RECORDS
      def error_line(log)
        return NO_RECORDS if log.include?(NO_RECORDS)

        lines = log.lines.map(&:strip).reject { |line| noise?(line) }
        lines.find { |line| line.match?(/error|exception/i) } ||
          lines.last ||
          "no error message found in log"
      end

      # Guess whether a line is important to us or not (i.e. discriminating
      # logic of error_line())
      def noise?(line)
        line.empty? ||
          line.match?(/\A=+\z/) ||
          line.match?(/\A\d+\. (STARTED|DONE):/) ||
          line.start_with?("Created: ") ||
          line.match?(/\A\S+\.xml\z/i)
      end

      def get!(path, options)
        response = client.get(path, options)
        check!(response)
        response.parsed
      end

      def check!(response)
        return if response.status_code == 200

        raise "HTTP #{response.status_code}: #{response.body.to_s.strip}"
      end
    end
  end
end
