# frozen_string_literal: true

module AspaceDataTools
  module Doc
    class UpdateLocales
      # @param force [Boolean] if false and locales file exists and
      #  was downloaded today, do not re-download.
      def initialize(force: false)
        @force = force
        @uri = ADT.config.locales_uri
        @target_path = ADT.locales_file
        @target_dir = File.dirname(target_path)
      end

      # @return [:failure] if the result of this method leaves the
      #   locales file missing
      # @return [:success] if a locales file is in place after this
      #   method is called
      def call
        FileUtils.mkdir_p(target_dir) unless Dir.exist?(target_dir)
        return get_file if !present?
        return :success if fresh? && !force

        backup
        result = get_file
        if result == :success
          FileUtils.rm(backup_path)
          return result
        end

        puts "WARNING: Could not download locales file from #{uri}. "\
          "Restoring backup."
        restore
        :success
      end

      def update
        backup if File.exist?(target_path)
        download
      end

      private

      attr_reader :force, :uri, :target_dir, :target_path

      def present? = File.exist?(target_path)

      def fresh? = present? && age_in_hrs < 24

      def age_in_hrs = (Time.now - File.birthtime(target_path)) / 3600

      def backup_path = "#{target_path}.bak"

      def backup = FileUtils.mv(target_path, backup_path)

      def get_file
        `curl -L -o #{target_path} #{uri}`
        ($?.exitstatus == 0) ? :success : :failure
      end

      def restore = FileUtils.mv(backup_path, target_path)
    end
  end
end
