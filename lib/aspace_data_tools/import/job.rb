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
    #
    # I think these are all the meaningful status conditions we can
    # derive. 
    Job = Struct.new(:row, :filepath, :repo, :job_id, :status, :message,
      keyword_init: true) do
      def pending? = status == :pending
    end
  end
end
