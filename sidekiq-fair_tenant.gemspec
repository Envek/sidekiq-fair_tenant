# frozen_string_literal: true

require_relative "lib/sidekiq/fair_tenant/version"

Gem::Specification.new do |spec|
  spec.name = "sidekiq-fair_tenant"
  spec.version = Sidekiq::FairTenant::VERSION
  spec.authors = ["Andrey Novikov"]
  spec.email = ["envek@envek.name"]

  spec.summary = "Throttle Sidekiq jobs of greedy tenants"
  spec.description = "Re-route jobs of way too active tenants to slower queues, letting other tenant's jobs to go first"
  spec.homepage = "https://github.com/Envek/sidekiq-fair_tenant"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Envek/sidekiq-fair_tenant"
  spec.metadata["changelog_uri"] = "https://github.com/Envek/sidekiq-fair_tenant/blob/master/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ spec/ Gemfile Rakefile]) ||
        f.match(/^(\.)/)
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "anyway_config", ">= 1.0", "< 3"
  spec.add_dependency "sidekiq", ">= 5"
end
