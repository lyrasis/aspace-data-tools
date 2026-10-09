# frozen_string_literal: true

require "csv"

module AspaceDataTools
  # Writes a batch report CSV: every column and row of the input CSV, in the
  # original order, followed by columns describing what happened to each row.
  class BatchCsvReport
    # @param path [String] where to write the report
    # @param headers [Array<String>] input CSV headers
    # @param rows [Array<Array(CSV::Row, Hash)>] each input row paired with a
    #   Hash of result column => value
    def initialize(path:, headers:, rows:)
      @path = path
      @headers = headers
      @rows = rows
    end

    def call
      CSV.open(path, "w") do |csv|
        csv << all_headers
        rows.each { |row, results| csv << values(row, results) }
      end
      path
    end

    private

    attr_reader :path, :headers, :rows

    # Convenience functions for building headers and mapping output to rows
    def all_headers
      @all_headers ||= headers + (result_headers - headers)
    end

    def result_headers
      rows.flat_map { |_row, results| results.keys.map(&:to_s) }.uniq
    end

    def values(row, results)
      merged = row.to_h.merge(results.transform_keys(&:to_s))
      all_headers.map { |hdr| merged[hdr] }
    end
  end
end
