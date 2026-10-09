# frozen_string_literal: true

require "tmpdir"

RSpec.describe ADT::Import::Results do
  # Make up some parameters for testing import logic: 
  let(:repo) { "2" }
  let(:job_id) { 7 }
  let(:records_path) { "repositories/#{repo}/jobs/#{job_id}/records" }
  let(:log_path) { "repositories/#{repo}/jobs/#{job_id}/log" }
  let(:job_status) { "completed" }
  let(:job) do
    ADT::Import::Job.new(repo: repo, job_id: job_id, job_status: job_status,
      filepath: "/eads/collection_1.xml", status: :submitted)
  end
  let(:no_records_log) do
    File.read(fixture_path("import", "no_records.log"))
  end
  let(:routes) { {} }
  let(:client) { FakeClient.new(routes) }

  around do |example|
    Dir.mktmpdir do |dir|
      @tmpdir = dir
      example.run
    end
  end

  # nested, not-yet-existing dir, to check it gets created
  let(:log_dir) { File.join(@tmpdir, "report_logs") }

  def resolve_jobs(*jobs)
    results = described_class.new(client: client,
      primary: ADT::Import::Batch::IMPORT_TYPES["ead_xml"][:primary],
      log_dir: log_dir)
    expect { results.call(jobs) }.to output.to_stdout
  end

  def resource(id) = "/repositories/#{repo}/resources/#{id}"

  def ao(id) = "/repositories/#{repo}/archival_objects/#{id}"

  describe "final status" do
    context "when completed with one resource" do
      let(:routes) do
        {records_path => FakeClient.records([ao(1), resource(10)])}
      end

      it "succeeds with the resource uri" do
        resolve_jobs(job)
        expect(job.status).to eq(:success)
        expect(job.record_created_uri).to eq(resource(10))
        expect(job.message).to be_nil
      end

      it "does not write a log" do
        resolve_jobs(job)
        expect(client.requests.map(&:first)).not_to include(log_path)
        expect(job.log_path).to be_nil
      end
    end

    context "when completed with multiple resources" do
      let(:routes) do
        {records_path => FakeClient.records([resource(10), resource(11)])}
      end

      it "succeeds with the first, listing all in the message" do
        resolve_jobs(job)
        expect(job.status).to eq(:success)
        expect(job.record_created_uri).to eq(resource(10))
        expect(job.message).to include(resource(10), resource(11))
      end
    end

    context "when completed without a resource" do
      let(:routes) do
        {
          records_path => FakeClient.records([ao(1), "/agents/people/3"]),
          log_path => FakeClient.text(no_records_log)
        }
      end

      it "returns the expected no_record status" do
        resolve_jobs(job)
        expect(job.status).to eq(:no_record)
        expect(job.record_created_uri).to be_nil
      end
    end

    %w[failed canceled].each do |reported|
      context "when ArchivesSpace reports #{reported}" do
        let(:job_status) { reported }
        let(:routes) do
          {
            records_path => FakeClient.records([resource(10)]),
            log_path => FakeClient.text("Something went wrong")
          }
        end

        it "is marked failed even if records were created (import_failed)" do
          resolve_jobs(job)
          expect(job.status).to eq(:import_failed)
          expect(job.record_created_uri).to be_nil
        end
      end
    end
  end

  describe "paging through created records" do
    let(:routes) do
      pages = {
        1 => [ao(1), ao(2)],
        2 => [ao(3), nil],
        3 => [resource(10)]
      }
      {
        records_path => ->(page) {
          FakeClient.records(pages.fetch(page), last_page: 3)
        }
      }
    end

    it "requests each page (once) up to and including last_page" do
      resolve_jobs(job)
      expect(client.requests).to eq(
        [[records_path, 1], [records_path, 2], [records_path, 3]]
      )
    end

    it "keeps every uri in order, dropping items without a ref" do
      resolve_jobs(job)
      expect(job.record_uris).to eq([ao(1), ao(2), ao(3), resource(10)])
    end
  end

  describe "error message from the log" do
    let(:job_status) { "failed" }
    let(:routes) do
      {
        records_path => FakeClient.records([]),
        log_path => FakeClient.text(log)
      }
    end

    context "with the no-records log" do
      let(:log) { no_records_log }

      it "uses the no-records line" do
        resolve_jobs(job)
        expect(job.message).to eq(described_class::NO_RECORDS)
      end
    end

    # Failed job log format from a sample EAD.
    context "with an exception and stack trace" do
      let(:log) do
        <<~LOG
          ==================================================
          ead3_multi_level_optimum.xml
          ==================================================
          
          IMPORT ERROR
          The following errors were found:
          	title: Property is required but was missing
          
          
           For JSONModel(:digital_object): 
           #<JSONModel(:digital_object) {"jsonmodel_type"=>"digital_object", "external_ids"=>[], "subjects"=>[], "linked_events"=>[], "extents"=>[], "lang_materials"=>[], "dates"=>[], "external_documents"=>[], "rights_statements"=>[], "linked_agents"=>[], "is_slug_auto"=>true, "file_versions"=>[{"file_uri"=>"http://library.marist.edu/archives/LTP/digitizedContents/Box%20495/1.25.1.1.495.2.pdf", "publish"=>true, "is_representative"=>false}], "restrictions"=>false, "classifications"=>[], "notes"=>[], "collection"=>[], "linked_instances"=>[], "metadata_rights_declarations"=>[], "uri"=>"/repositories/import/digital_objects/import_123725e4-8746-45cd-b33e-c4b9b682b092", "digital_object_id"=>"89fe52e8-0729-40f1-b5c7-d5c3580be3fe", "publish"=>true}>
          
          
          In : 
           &lt;dao class=&quot;cdata&quot; daotype=&quot;derived&quot; href=&quot;http://library.marist.edu/archives/LTP/digitizedContents/Box%20495/1.25.1.1.495.2.pdf&quot;&gt; ... &lt;/dao&gt;
        LOG
      end

      it "uses the exception line, not the last trace line" do
        resolve_jobs(job)
        expect(job.message)
          .to eq("IMPORT ERROR")
      end
    end

    # Omit the "no records" line and confirm that we see no errors
    # once it's gone: 
    context "with only banner and progress lines" do
      let(:log) do
        no_records_log.lines.reject { |l| l.include?("No records") }.join
      end

      it "says no message was found" do
        resolve_jobs(job)
        expect(job.message).to eq("no error message found in log")
      end
    end
  end

  describe "fetch errors" do
    let(:other) do
      ADT::Import::Job.new(repo: repo, job_id: 8, job_status: "completed",
        filepath: "/eads/collection_2.xml", status: :submitted)
    end
    let(:other_routes) do
      {"repositories/#{repo}/jobs/8/records" =>
        FakeClient.records([resource(20)])}
    end

    # create an "internal server error"
    context "when the records request returns HTTP 500" do
      let(:routes) do
        {records_path => FakeClient.text("fido", status: 500)}
          .merge(other_routes)
      end

      it "marks that job unresolved and still resolves the others (500)" do
        resolve_jobs(job, other)
        expect(job.status).to eq(:unresolved)
        expect(job.message).to include("HTTP 500")
        expect(other.status).to eq(:success)
      end
    end

    context "when the log request raises" do
      let(:routes) do
        {
          records_path => FakeClient.records([]),
          log_path => Errno::ECONNRESET.new
        }.merge(other_routes)
      end

      it "marks that job unresolved and still resolves the others (reset)" do
        resolve_jobs(job, other)
        expect(job.status).to eq(:unresolved)
        expect(job.message).to include("ECONNRESET")
        expect(other.status).to eq(:success)
      end
    end
  end

  describe "log files" do
    let(:routes) do
      {
        records_path => FakeClient.records([]),
        log_path => FakeClient.text(no_records_log)
      }
    end

    # Confirm that we get an output log where expected. Possible improvement
    # would be to derive this filename on the fly instead of having the
    # magic string but ok for now
    it "creates the log dir and writes <job_id>_<basename>.log" do
      resolve_jobs(job)
      expect(job.log_path).to eq(File.join(log_dir, "7_collection_1.log"))
      expect(File.read(job.log_path)).to eq(no_records_log)
    end
  end
end
