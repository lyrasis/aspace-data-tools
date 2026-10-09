# frozen_string_literal: true

require "csv"

module AspaceDataTools
  module Import
    # Writes the outputs of a batch import:
    #   - the report CSV: every manifest column plus the result columns
    #   - a records CSV beside it (<report>_records.csv), with one row per
    #     record created by any job
    class Report
      RECORDS_HEADERS = %w[job_id filepath repo uri].freeze

      # @param path [String] path of report CSV
      # @param headers [Array<String>] manifest headers
      # @param jobs [Array<Job>]
      def initialize(path:, headers:, jobs:)
        @path = path
        @headers = headers
        @jobs = jobs
      end

      def call
        BatchCsvReport.new(
          path: path,
          headers: headers,
          rows: jobs.map { |job| [job.row, result_columns(job)] }
        ).call
        write_records
        puts "Wrote report to #{path}"
        puts "Wrote created record uris to #{records_path}"
      end

      # Ensure that records filename matches report
      def records_path = path.sub(/(\.csv)?\z/i, "_records.csv")

      private

      attr_reader :path, :headers, :jobs

      # Map columns to actual job data
      def result_columns(job)
        {
          "job_id" => job.job_id,
          "job_status" => job.job_status,
          "status" => job.status,
          "record_created_uri" => job.record_created_uri,
          "error_message" => job.message,
          "log_path" => job.log_path
        }
      end

      # Convenience function for writing the records report
      def write_records
        CSV.open(records_path, "w") do |csv|
          csv << RECORDS_HEADERS
          jobs.each do |job|
            (job.record_uris || []).each do |uri|
              csv << [job.job_id, job.filepath, job.repo, uri]
            end
          end
        end
      end
    end
  end
end
