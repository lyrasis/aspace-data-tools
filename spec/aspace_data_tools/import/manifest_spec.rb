# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe ADT::Import::Manifest do
  around do |example|
    Dir.mktmpdir do |dir|
      @tmpdir = dir
      example.run
    end
  end

  # Manifest lives in a subdirectory so relative paths have somewhere to go
  # for testing purposes.
  let(:manifest_dir) { File.join(@tmpdir, "batch") }
  let(:manifest_path) { File.join(manifest_dir, "manifest.csv") }
  let(:manifest) { described_class.new(path: manifest_path, repo_ids: [2, 3]) }

  def write_manifest(csv)
    FileUtils.mkdir_p(manifest_dir)
    File.write(manifest_path, csv)
  end

  # Creates an (empty) EAD file and returns its absolute path. This is just a
  # stub generator that saves us the trouble of making standalone fixtures,
  # which aren't really necessary for testing the straitghtforward manifest.
  def ead(relpath)
    path = File.expand_path(relpath, manifest_dir)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "<ead/>")
    path
  end

  def only_job(filepath:, repo:)
    write_manifest("filepath,repo\n#{filepath},#{repo}\n")
    manifest.jobs.first
  end

  describe "a valid row" do
    it "is pending with no message" do
      ead("a.xml")
      job = only_job(filepath: "a.xml", repo: "2")
      expect(job.status).to eq(:pending)
      expect(job.message).to be_nil
      expect(job.repo).to eq("2")
    end
  end

  # This test is about specific reasons for skipping rows. The array of
  # arrays is just a matrix of test conditions:
  #
  #  [ reason for skipping, input file, target repo, why failed ]
  #
  describe "skip reasons" do
    before { ead("a.xml") }

    [
      ["blank filepath", "", "2", "filepath is blank"],
      ["blank repo", "a.xml", "", "repo is blank"],
      ["non-numeric repo", "a.xml", "two", "repo is not a numeric id: two"],
      ["repo not in ArchivesSpace", "a.xml", "9",
        "repo 9 does not exist in ArchivesSpace"]
    ].each do |reason, filepath, repo, message|
      it "skips a row with #{reason}" do
        job = only_job(filepath: filepath, repo: repo)
        expect(job.status).to eq(:skipped)
        expect(job.message).to eq(message)
      end
    end

    it "skips a row whose file does not exist, showing the resolved path" do
      job = only_job(filepath: "nope.xml", repo: "2")
      expect(job.status).to eq(:skipped)
      expect(job.message)
        .to eq("file not found: #{File.join(manifest_dir, "nope.xml")}")
    end
  end

  # Make sure the desired file is the one actually getting loaded when
  # a relative path is supplied (still recommend absolute paths)
  describe "file paths" do
    it "resolves relative paths against the manifest's directory (.)" do
      expected = ead("eads/a.xml")
      job = only_job(filepath: "eads/a.xml", repo: "2")
      expect(job.filepath).to eq(expected)
      expect(job.status).to eq(:pending)
    end

    it "resolves paths that go above the manifest's directory (..)" do
      expected = ead("../elsewhere/a.xml")
      job = only_job(filepath: "../elsewhere/a.xml", repo: "2")
      expect(job.filepath).to eq(expected)
      expect(job.status).to eq(:pending)
    end

    # Ensure jobs are not altering absolute paths:
    it "leaves absolute paths unchanged" do
      expected = ead(File.join(@tmpdir, "absolute", "a.xml"))
      job = only_job(filepath: expected, repo: "2")
      expect(job.filepath).to eq(expected)
      expect(job.status).to eq(:pending)
    end
  end

  # Does one row = 1 job, regardless of any extra columns in the manifest?
  describe "rows" do
    it "gives one job per row, in order, keeping extra columns" do
      ead("a.xml")
      write_manifest(
        "filepath,repo,note\na.xml,2,first\nmissing.xml,3,second\n"
      )
      jobs = manifest.jobs
      expect(jobs.map(&:status)).to eq(%i[pending skipped])
      expect(jobs.map { |job| job.row["note"] }).to eq(%w[first second])
      expect(manifest.headers).to eq(%w[filepath repo note])
    end
  end

  # Parsing should break if there's no manifest file at the specfied path
  # (or we can't read it for some other reason). It should also fail if
  # one or both of the required column headers can't be found.
  describe "conditions that stop parsing" do
    it "raises if the manifest does not exist" do
      expect { manifest.jobs }
        .to raise_error(RuntimeError, /Manifest not found: #{manifest_path}/)
    end

    it "raises if the filepath column is missing" do
      write_manifest("path,repo\na.xml,2\n")
      expect { manifest.jobs }
        .to raise_error(RuntimeError, /column\(s\): filepath\z/)
    end

    it "raises if the repo column is missing" do
      write_manifest("filepath,repository\na.xml,2\n")
      expect { manifest.jobs }
        .to raise_error(RuntimeError, /column\(s\): repo\z/)
    end

    it "raises if both required columns are missing" do
      write_manifest("file,repository\na.xml,2\n")
      expect { manifest.jobs }
        .to raise_error(RuntimeError, /column\(s\): filepath, repo\z/)
    end
  end
end
