# frozen_string_literal: true

require "csv"
require "tmpdir"

RSpec.describe ADT::BatchCsvReport do
  around do |example|
    Dir.mktmpdir do |dir|
      @report_path = File.join(dir, "report.csv")
      example.run
    end
  end

  # Input rows as the manifest provides them: CSV::Row objects
  let(:input) { CSV.parse(input_csv, headers: true) }

  # Writes the report and returns it as arrays (header row first),
  # allowing easy checks of the output.
  #
  # This is a convenience function that creates a new BatchCsvReport
  # (the described_class) from a supplied data fixture, as shown in
  # the calls below.
  def write_report(results)
    described_class.new(
      path: @report_path,
      headers: input.headers,
      rows: input.each.zip(results)
    ).call
    CSV.read(@report_path)
  end

  # This test checks to see if columns are kept in order between input and
  # reporting:
  describe "column order" do
    let(:input_csv) { "repo,filepath,note\n2,a.xml,first\n3,b.xml,second\n" }

    it "keeps input columns in order, followed by result columns" do
      report = write_report([
        {"job_id" => 1, "status" => "success"},
        {"job_id" => 2, "status" => "failed"}
      ])
      expect(report).to eq([
        %w[repo filepath note job_id status],
        %w[2 a.xml first 1 success],
        %w[3 b.xml second 2 failed]
      ])
    end
  end

  # If we have a "protected" column header in the input--in this case,
  # `status`--we replace the input value and do not duplicate the column.
  # This helps enforce clarity in the reports without breaking, clobbering
  # the batch manifest, etc. when minor collisions happen.
  describe "result column with the same name as an input column" do
    let(:input_csv) { "filepath,status,repo\na.xml,old,2\n" }

    it "replaces the input value in place, without a duplicate column" do
      report = write_report([{"status" => "new", "job_id" => 1}])
      expect(report).to eq([
        %w[filepath status repo job_id],
        %w[a.xml new 2 1]
      ])
    end
  end

  # It's fine to have missing data in a row of the batch CSV (in the sense
  # that it shouldn't break anything), so let's make sure that nothing breaks
  # from bogus data when writing results 
  describe "rows with missing data" do
    let(:input_csv) { "filepath\na.xml\nb.xml\nc.xml\n" }

    it "writes every result column anyway, leaving missing and nil values"\
      " empty" do
      report = write_report([
        {"job_id" => 1},
        {"error_message" => "fido", "job_id" => nil},
        {log_path: "/logs/3.log"}
      ])
      expect(report).to eq([
        %w[filepath job_id error_message log_path],
        ["a.xml", "1", nil, nil],
        ["b.xml", nil, "fido", nil],
        ["c.xml", nil, nil, "/logs/3.log"]
      ])
    end
  end
end
