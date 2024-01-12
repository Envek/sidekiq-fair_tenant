# frozen_string_literal: true

require "bundler/setup"
require "active_job"
require "active_job/queue_adapters/sidekiq_adapter"
require "active_support/core_ext/numeric/time"
require "active_support/testing/time_helpers"
require "sidekiq/testing"
require "rspec-sidekiq"

require "sidekiq/fair_tenant"

require_relative "support/jobs"

RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.mock_with :rspec

  Kernel.srand config.seed
  config.order = :random

  config.after do
    travel_back
    Sidekiq::Queues.clear_all

    Sidekiq.redis do |redis|
      if redis.respond_to?(:scan_each)
        redis.scan_each(match: "sidekiq-fair_tenant:*", &redis.method(:del))
      else
        redis.scan(match: "sidekiq-fair_tenant:*").each(&redis.method(:del))
      end
    end
  end
end

ActiveJob::Base.logger = Logger.new(nil)
