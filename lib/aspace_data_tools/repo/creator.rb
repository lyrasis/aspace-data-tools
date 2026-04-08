# frozen_string_literal: true

module AspaceDataTools
  module Repo
    class Creator
      # @param options [Hash]
      # @option options [String] :repo_code
      # @option options [NilValue, String] :name
      # @option options [NilValue, String] :agent_contact_name
      def initialize(options)
        @repo_code = options[:repo_code]
        @name = options[:name] || repo_code.upcase
        @agent_contact_name = options[:agent_contact_name] || repo_code.upcase
        @client = ADT.client
      end

      def call
        puts ArchivesSpace::Template.list

        record = ArchivesSpace::Template.process(
          "repository_with_agent.json.erb", repo_data
        )
        ingest(record)
      end

      private

      attr_reader :repo_code, :name, :agent_contact_name, :client

      def repo_data
        {
          repo_code: repo_code,
          name: name,
          agent_contact_name: agent_contact_name
        }
      end

      def ingest(record)
        response = client.post("/repositories/with_agent", record)
        if response.result.success?
          puts "Successfully created repository: #{repo_code}"
        else
          puts "Could not create repository: #{repo_code}"
        end
        puts response.parsed
      rescue ArchivesSpace::RequestError => e
        puts "Could not create repository: #{repo_code}"
        puts e.message
      end
    end
  end
end
