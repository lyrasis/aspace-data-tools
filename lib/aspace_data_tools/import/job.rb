# frozen_string_literal: true

module AspaceDataTools
  module Import
    # One manifest row and what has happened to it so far. Filepath
    # and repo are supplied.
    #
    # status values:
    #   :pending - valid row, not yet submitted
    #   :skipped - row failed manifest validation; never submitted
    #   :submitted - import job created in ArchivesSpace
    #   :failed - job submission was attempted and failed
    #   :timeout - job had not finished when polling gave up
    #   :success - job completed and created the expected primary record
    #   :no_record - job completed but created no primary record
    #   :import_failed - ArchivesSpace reported the job failed or canceled
    #   :unresolved - job finished, but its records or log could not be
    #     retrieved
    #
    # job_status is the job's status as last reported by ArchivesSpace
    # (queued, running, completed, failed, canceled). It is kept separate
    # from status because "completed" does not mean the import worked.
    #
    # record_uris holds every record the job created; record_created_uri
    # is the one matching the import type's primary pattern.
    Job = Struct.new(:row, :filepath, :repo, :job_id, :status, :job_status,
      :message, :record_created_uri, :record_uris, :log_path,
      keyword_init: true) do
      def pending? = status == :pending
    end
  end
end
