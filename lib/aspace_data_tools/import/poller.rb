# frozen_string_literal: true

module AspaceDataTools
  module Import
    # Waits for submitted import jobs to finish, recording each job's
    # ArchivesSpace status in job_status.
    #
    # This module doesn't "know" whether a finished job matches the user
    # intent. A job can complete without having created anything, so 
    # we determine "success"/"failure" in that sense in the next phase 
    # (reporting on results). This is about the job finishing or not. 
    class Poller
      FINISHED = %w[completed failed canceled].freeze

      # @param client [ArchivesSpace::Client]
      # @param interval [Numeric] seconds to wait between rounds of checks.
      # Adjustable with --poll-interval
      # @param timeout [Numeric] seconds to wait before giving up on
      # unfinished jobs. 10 minutes per ingest feels generous, but this
      # value can be changed with --timeout)
      def initialize(client:, interval: 5, timeout: 600)
        @client = client
        @interval = interval
        @timeout = timeout
      end

      # @param jobs [Array<Job>] submitted jobs
      # @return [Array<Job>] jobs that finished. Unfinished jobs are given
      # status :timeout and left running in ArchivesSpace.
      def call(jobs)
        outstanding = jobs.dup
        deadline = now + timeout
        @last_counts = nil

        # go for it until there are no unfinished jobs OR timeout passes.
        # Report progress on each unfinished job before sleeping.
        until outstanding.empty? || now > deadline
          outstanding.each { |job| refresh(job) }
          outstanding.reject! { |job| finished?(job) }
          report_progress(jobs)
          sleep interval unless outstanding.empty?
        end

        # if we're here because the deadline has passed,
        # flag remaining jobs as timed out (which is 
        # effectively no-op if outstanding is empty)
        outstanding.each { |job| job.status = :timeout }
        jobs - outstanding
      end

      private

      attr_reader :client, :interval, :timeout

      def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # check to see if a job is in one of the 3 finished states:
      def finished?(job) = FINISHED.include?(job.job_status)

      # A failed check leaves job_status as-is, so the job is checked again
      # next round. The error is kept in message in case it never recovers.
      def refresh(job)
        response = client.get("repositories/#{job.repo}/jobs/#{job.job_id}")
        status = response.parsed["status"] if response.parsed.is_a?(Hash)
        unless response.status_code == 200 && status
          job.message = "status check failed: HTTP #{response.status_code}"
          return
        end

        job.job_status = status
        job.message = nil
      rescue => err
        job.message = "status check failed: #{err.class}: #{err.message}"
      end

      # Print only when the counts have changed since the last round
      def report_progress(jobs)
        counts = jobs.map { |job| job.job_status || "unknown" }.tally
        return if counts == @last_counts

        @last_counts = counts
        puts "  " + counts.sort.map { |status, ct| "#{ct} #{status}" }
          .join(", ")
      end
    end
  end
end
