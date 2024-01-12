# frozen_string_literal: true

module Sidekiq
  module FairTenant
    # Client middleware re-routing jobs of overly active tenants to slower queues based on thresholds
    class ClientMiddleware
      # Re-routes job to the most appropriate queue, based on tenant's throttling rules
      # rubocop:disable Metrics/MethodLength
      def call(worker, job, queue, redis_pool)
        job_class = job_class(worker, job)
        arguments = job["wrapped"] ? job.dig("args", 0, "arguments") : job["args"]
        return yield unless enabled?(job_class, job, queue)

        job["fair_tenant"] ||= tenant_id(job_class, job, arguments)
        unless job["fair_tenant"]
          logger.warn "#{job_class} with args #{arguments.inspect} won't be throttled: missing `fair_tenant` in job"
          return yield
        end

        redis_pool.then do |redis|
          register_job(job_class, job, queue, redis)
          job["queue"] = assign_queue(job_class, job, queue, redis)
        end

        yield
      end
      # rubocop:enable Metrics/MethodLength

      private

      def enabled?(job_class, job, queue)
        return false if job["fair_tenant_queues"].blank? # Not configured for throttling

        original_queue = original_queue(job_class, job, queue)
        return false if original_queue != job["queue"] # Someone already rerouted this job, nothing to do here

        true
      end

      # Writes job to sliding window sorted set
      def register_job(job_class, job, queue, redis)
        enqueues_key = enqueues_key(job_class, job, queue)
        max_throttling_window = Sidekiq::FairTenant.max_throttling_window
        redis.multi do |tx|
          tx.zremrangebyscore(enqueues_key, "-inf", (Time.now - max_throttling_window).to_i)
          tx.zadd(enqueues_key, Time.now.to_i, "jid:#{job["jid"]}")
          tx.expire(enqueues_key, max_throttling_window)
        end
      end

      # Chooses the last queue, for the most restrictive (threshold/time) rule that is met.
      # Assumes the slowest queue, with most restrictive rule, comes last in the `fair_tenants` array.
      def assign_queue(job_class, job, queue, redis)
        enqueues_key = enqueues_key(job_class, job, queue)

        matching_rules =
          job["fair_tenant_queues"].map(&:symbolize_keys).filter do |config|
            threshold = config[:threshold]
            window_start = Time.now - (config[:per] || Sidekiq::FairTenant.max_throttling_window)
            threshold < redis.zcount(enqueues_key, window_start.to_i, Time.now.to_i)
          end

        matching_rules.any? ? matching_rules.last[:queue] : queue
      end

      def enqueues_key(job_class, job, queue)
        format(Sidekiq::FairTenant.enqueues_key, queue: queue, fair_tenant: job["fair_tenant"], job_class: job_class)
      end

      def job_class(worker, job)
        job_class = job["wrapped"] || worker
        return job_class if job_class.is_a?(Class)
        return job_class.constantize if job_class.respond_to?(:constantize)

        Object.const_get(job_class.to_s)
      end

      # Calculates tenant identifier (`fair_tenant`) for the job
      def tenant_id(job_class, job, arguments)
        return job_class.fair_tenant(*arguments) if job_class.respond_to?(:fair_tenant)

        job["apartment"] # for compatibility with sidekiq-apartment
      end

      def original_queue(job_class, _job, queue)
        if job_class.respond_to?(:queue_name)
          job_class.queue_name # ActiveJob
        elsif job_class.respond_to?(:queue)
          job_class.queue.to_s # Sidekiq
        else
          queue
        end
      end

      def logger
        Sidekiq::FairTenant.logger
      end
    end
  end
end
