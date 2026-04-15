# frozen_string_literal: true

ruby File.read(".ruby-version").strip

source "https://rubygems.org"

gem "archivesspace-client", github: "lyrasis/archivesspace-client",
  branch: "master"
gem "bigdecimal"
gem "csv"
gem "json-schema", "1.0.10" # pinned to version used in AS
gem "prism"
gem "psych"
gem "table_tennis"
gem "thor"
gem "zeitwerk"

group :development do
  gem "asciidoctor", "~> 2.0"
  gem "almost_standard", github: "kspurgin/almost_standard", branch: "main"
  gem "yard", "~> 0.9"
end

group :test do
  gem "rspec"
end

gem "pry", "~> 0.14", groups: [:development, :test]
