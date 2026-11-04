# frozen_string_literal: true

# Set up some plumbing with the stub client and declare a basic job
# generator function, job().
RSpec.describe ADT::Import::Poller do
  let(:repo) { "2" }
  let(:routes) { {} }
  let(:client) { FakeClient.new(routes) }

  def job(id)
    ADT::Import::Job.new(repo: repo, job_id: id, status: :submitted)
  end

  def job_path(id) = "repositories/#{repo}/jobs/#{id}"

  # A route answering one entry per poll, repeating the last one. Entries
  # are a job status string, an HTTP error code, or an exception to raise.
  #
  # `seq` contains an arbitrary number of expected outcomes. 
  def statuses(*seq)
    # calls is just a local counter that the lambda can use. The lambda
    # itself clamps the index in seq[] so that it's in bounds, increments
    # the number of calls, and switches over entry to figure out how to
    # handle it. If exception, raise; if integer (status code), then generate
    # a response from it by calling .text(); otherwise, use .json()
    calls = 0
    lambda do |_page|
      entry = seq[[calls, seq.length - 1].min]
      calls += 1
      case entry
      when Exception then raise entry
      when Integer then FakeClient.text("error", status: entry)
      else FakeClient.json({"status" => entry})
      end
    end
  end

  # Short interval and timeout keep "stuck job" examples fast. Even 1.0s
  # creates an irritating delay in running the tests, but we just need 
  # literally any positive value.
  def poll(*jobs, timeout: 0.05)
    poller = described_class.new(client: client, interval: 0.01,
      timeout: timeout)
    finished = nil
    expect { finished = poller.call(jobs) }.to output.to_stdout
    finished
  end

  # convenience function to count how many times a job's status has
  # been checked by the poller 
  def checks_of(id) = client.requests.count { |path, _| path == job_path(id) }

  describe "normal jobs" do
    # This is just simulating a few plausible job conditions. The
    # values in the statuses splat should match ASpace job statuses.
    let(:routes) do
      {
        job_path(1) => statuses("queued", "running", "completed"),
        job_path(2) => statuses("queued", "failed"),
        job_path(3) => statuses("canceled")
      }
    end

    it "waits for every job to finish, recording job_status" do
      jobs = [job(1), job(2), job(3)]
      expect(poll(*jobs, timeout: 5)).to eq(jobs)
      expect(jobs.map(&:job_status)).to eq(%w[completed failed canceled])
    end

    it "leaves status alone for the results step to decide" do
      jobs = [job(1), job(2), job(3)]
      poll(*jobs, timeout: 5)
      expect(jobs.map(&:status)).to all(eq(:submitted))
    end
  end

  describe "stuck jobs" do
    let(:routes) do
      {
        job_path(1) => statuses("completed"),
        job_path(2) => statuses("running")
      }
    end

    it "marks unfinished jobs :timeout and returns only finished ones" do
      done, stuck = job(1), job(2)
      expect(poll(done, stuck)).to eq([done])
      expect(stuck.status).to eq(:timeout)
      expect(stuck.job_status).to eq("running")
    end
  end

  describe "error recovery" do
    context "when checks keep failing with an HTTP error" do
      let(:routes) { {job_path(1) => statuses(500)} }

      it "records the error in message" do
        failing = job(1)
        poll(failing)
        expect(failing.message).to eq("status check failed: HTTP 500")
        expect(failing.job_status).to be_nil
      end
    end

    context "when checks keep raising" do
      let(:routes) { {job_path(1) => statuses(Errno::ECONNRESET.new)} }

      it "records the exception in message" do
        failing = job(1)
        poll(failing)
        expect(failing.message)
          .to start_with("status check failed: Errno::ECONNRESET")
      end
    end

    context "when a check fails and a later one succeeds" do
      let(:routes) do
        {job_path(1) => statuses(Errno::ECONNRESET.new, 500, "completed")}
      end

      it "finishes the job and clears the message" do
        recovering = job(1)
        expect(poll(recovering, timeout: 5)).to eq([recovering])
        expect(recovering.job_status).to eq("completed")
        expect(recovering.message).to be_nil
      end
    end
  end

  describe "checking finished jobs" do
    let(:routes) do
      {
        job_path(1) => statuses("completed"),
        job_path(2) => statuses("queued", "running", "completed")
      }
    end

    it "does not check a job again once it has finished" do
      poll(job(1), job(2), timeout: 5)
      expect(checks_of(1)).to eq(1)
      expect(checks_of(2)).to eq(3)
    end
  end
end
