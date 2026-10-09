# frozen_string_literal: true

# Stands in for ArchivesSpace::Client in specs, so no live client is actually
# required for testing. Routes map a "request" path to one of:
#   - a FakeResponse
#   - a Proc taking the requested page number and returning a FakeResponse
#   - an Exception, which is raised
class FakeClient
  FakeResponse = Struct.new(:status_code, :parsed, :body)

  # @return [Array<Array(String, Integer)>] path and page of each GET
  attr_reader :requests

  def initialize(routes)
    @routes = routes
    @requests = []
  end

  def get(path, options = {})
    page = options.dig(:query, :page)
    requests << [path, page]
    route = @routes.fetch(path) { raise "unexpected GET #{path}" }
    raise route if route.is_a?(Exception)

    route.respond_to?(:call) ? route.call(page) : route
  end

  def self.json(parsed, status: 200) = FakeResponse.new(status, parsed, "")

  def self.text(body, status: 200) = FakeResponse.new(status, nil, body)

  # One page of a job's created records
  def self.records(refs, last_page: 1)
    json({
      "last_page" => last_page,
      "results" => refs.map { |ref| {"record" => {"ref" => ref}} }
    })
  end
end
