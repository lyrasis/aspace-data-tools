# frozen_string_literal: true

require "csv"

module AspaceDataTools
  module Import
    # Reads and validates a file-level import manifest CSV
    #
    # REQUIRED_HEADERS must appear in the CSV: 
    #   filepath - path to the file to import. To avoid surprises, this
    #    should really be an absolute path. Relative paths are relative
    #    to the manifest file, so using `y/z.xml` as a filepath in
    #    ~/data/whatever/manifest.csv will resolve to ~/data/whatever/y/z.xml.
    #   repo - database id of the repository to import into.
    #
    # Other columns are kept as-is on each Job's row for later reporting.
    class Manifest
      REQUIRED_HEADERS = %w[filepath repo].freeze

      # @param path [String] path to manifest CSV
      # @param repo_ids [Array<String, Integer>] ids of repositories that
      #   exist in the target ArchivesSpace instance
      def initialize(path:, repo_ids:)
        @path = File.expand_path(path)
        @repo_ids = repo_ids.map(&:to_s)
      end

      # @return [Array<Job>] one per row. Invalid rows have status :skipped
      # set after checking validate(); cf. `build_job`. 
      def jobs
        @jobs ||= csv.map { |row| build_job(row) }
      end

      def headers = csv.headers

      private

      attr_reader :path, :repo_ids

      def csv
        @csv ||= read_csv
      end

      # Load the manifest CSV and make sure headers are as expected.
      # This file should be a plain UTF-8 text file. 
      def read_csv
        fail("‼️ Manifest not found: #{path}") unless File.file?(path)

        data = CSV.read(path, headers: true, skip_blanks: true,
          encoding: "bom|utf-8")
        missing = REQUIRED_HEADERS - data.headers
        unless missing.empty?
          fail("‼️ Manifest missing required column(s): #{missing.join(", ")}")
        end

        data
      end

      # Build an import job for a given row of the CSV. Piece out the
      # target repository, complete file path for import, and any
      # problems identified by validate().
      def build_job(row)
        filepath = row["filepath"].to_s.strip
        repo = row["repo"].to_s.strip
        fullpath = resolve(filepath)
        problem = validate(filepath, fullpath, repo)

        Job.new(
          row: row,
          filepath: fullpath,
          repo: repo,
          # i.e., mark this row skipped if problem != nil
          status: problem ? :skipped : :pending,
          message: problem
        )
      end

      # Convenience wrapper for expand_path
      def resolve(filepath)
        return if filepath.empty?

        File.expand_path(filepath, File.dirname(path))
      end

      # Assess some possible problems with this work: file to import
      # doesn't exist, repo wasn't supplied or wasn't numeric, repo
      # doesn't exist
      def validate(filepath, fullpath, repo)
        return "filepath is blank" if filepath.empty?
        return "file not found: #{fullpath}" unless File.file?(fullpath)
        return "repo is blank" if repo.empty?
        return "repo is not a numeric id: #{repo}" unless repo.match?(/\A\d+\z/)
        unless repo_ids.include?(repo)
          return "repo #{repo} does not exist in ArchivesSpace"
        end

        nil
      end
    end
  end
end
