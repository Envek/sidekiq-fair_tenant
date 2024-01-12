# frozen_string_literal: true

require "sidekiq"

require_relative "fair_tenant/version"
require_relative "fair_tenant/config"
require_relative "fair_tenant/client_middleware"

module Sidekiq
  # Client middleware and job DSL for throttling jobs of overly active tenants
  module FairTenant
    class Error < ::StandardError; end

    class << self
      extend ::Forwardable

      def config
        @config ||= Config.new
      end

      def_delegators :config, :max_throttling_window, :enqueues_key, :logger
    end
  end
end

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::FairTenant::ClientMiddleware
  end
end

Sidekiq.configure_server do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::FairTenant::ClientMiddleware
  end
end
