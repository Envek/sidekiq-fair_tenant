# frozen_string_literal: true

require "anyway"

module Sidekiq
  module FairTenant
    # Runtime configuration for the sidekiq-fair_tenant gem
    class Config < ::Anyway::Config
      config_name :sidekiq_fair_tenant

      # Maximum amount of time to store information about tenant enqueues
      attr_config max_throttling_window: 86_400 # 1 day

      # Sorted set that contains job ids enqueued by each tenant in last 1 day (max throttling window)
      attr_config enqueues_key: "sidekiq-fair_tenant:enqueued:%<job_class>s:tenant:%<fair_tenant>s"

      # Logger to use for throttling warnings
      attr_config logger: ::Sidekiq.logger
    end
  end
end
