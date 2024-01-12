# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# rubocop:disable Bundler/DuplicatedGem
sidekiq_version = ENV.fetch("SIDEKIQ_VERSION", "~> 7.2")
case sidekiq_version
when "HEAD"
  gem "sidekiq", git: "https://github.com/sidekiq/sidekiq.git"
else
  sidekiq_version = "~> #{sidekiq_version}.0" if sidekiq_version.match?(/^\d+(?:\.\d+)?$/)
  gem "sidekiq", sidekiq_version
end

activejob_version = ENV.fetch("ACTIVEJOB_VERSION", "~> 7.1")
case activejob_version
when "HEAD"
  git "https://github.com/rails/rails.git" do
    gem "activejob"
    gem "activesupport"
    gem "rails"
  end
else
  activejob_version = "~> #{activejob_version}.0" if activejob_version.match?(/^\d+\.\d+$/)
  gem "activejob", activejob_version
  gem "activesupport", activejob_version
end
# rubocop:enable Bundler/DuplicatedGem

gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

gem "rspec-sidekiq"

gem "rubocop", "~> 1.21", require: false
