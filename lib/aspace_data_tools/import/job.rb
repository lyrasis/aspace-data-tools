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
    #
    # job_status is the job's status as last reported by ArchivesSpace
    # (queued, running, completed, failed, canceled). It is kept separate
    # from status because "completed" does not mean the import worked.
    Job = Struct.new(:row, :filepath, :repo, :job_id, :status, :job_status,
      :message, keyword_init: true) do
      def pending? = status == :pending
    end
  end
end
