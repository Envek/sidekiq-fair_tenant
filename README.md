# Sidekiq::FairTenant

Throttle “greedy” clients’ jobs to ensure more or less fair distribution of resources between clients.

This tiny [Sidekiq] middleware will re-route client's jobs after certain threshold to throttled queues (defined by you), where they will be processed with reduced priority.

“Weighted queues” feature of Sidekiq allows to de-prioritize jobs in throttled queues, so they will not block jobs from other clients, at the same time preserving overall throughput.

<a href="https://evilmartians.com/?utm_source=sidekiq-fair_tenant">
  <picture>
    <source
      media="(prefers-color-scheme: dark)"
      srcset="https://evilmartians.com/badges/sponsored-by-evil-martians_v2.0_for-dark-bg@2x.png"
    >
    <img
      src="https://evilmartians.com/badges/sponsored-by-evil-martians_v2.0@2x.png"
      alt="Sponsored by Evil Martians"
      width="236"
      height="54"
    >
  </picture>
</a>

## Installation

 1. Install the gem and add to the application's Gemfile by executing:

    ```sh
    bundle add sidekiq-fair_tenant
    ```

 2. Add `fair_tenant_queues` section to `sidekiq_options` in your job class:

    ```diff
     class SomeJob
       sidekiq_options \
         queue: 'default',
    +    fair_tenant_queues: [
    +     { queue: 'throttled_2x', threshold: 100, per: 1.hour },
    +     { queue: 'throttled_4x', threshold:  10, per: 1.minute },
    +    ]
     end
    ```

 3. Add tenant detection login into your job class:

    ```diff
     class SomeJob
    +  def self.fair_tenant(*_perform_arguments)
    +    # Return any string that will be used as tenant name
    +    "tenant_1"
    +  end
     end
    ```

 4. Add throttled queues with reduced weights to your Sidekiq configuration:

    ```diff
     # config/sidekiq.yml
     :queues:
       - [default, 4]
    +  - [throttled_2x, 2]
    +  - [throttled_4x, 1]
    ```

    See [Sidekiq Advanced options for Queues](https://github.com/sidekiq/sidekiq/wiki/Advanced-Options#queues) to learn more about queue weights.

## Usage

### Specifying throttling rules

In your job class, add `fair_tenant_queues` section to `sidekiq_options` as array of hashes with following keys:

 - `queue` - throttled queue name to re-route jobs into.
 - `threshold` - maximum number of jobs allowed to be enqueued within `per` seconds.
 - `per` - sliding time window in seconds to count jobs (you can use ActiveSupport Durations in Rails).

You can specify multiple rules and they all will be checked. _Last_ matching rule will be used, so order rules from least to most restrictive.

Example:

```ruby
sidekiq_options \
  queue: 'default',
  fair_tenant_queues: [
    # First rule is less restrictive, reacting to a large number of jobs enqueued in a long time window
    { queue: 'throttled_2x', threshold: 1_000, per: 1.day },
    # Next rule is more restrictive, reacting to spikes of jobs in a short time window
    { queue: 'throttled_4x', threshold:    10, per: 1.minute },
  ]
```

### Specifying tenant

 1. Explicitly during job enqueuing:

    ```ruby
    SomeJob.set(fair_tenant: 'tenant_1').perform_async
    ```

 2. Dynamically using `fair_tenant` class-level method in your job class (receives same arguments as `perform`)

    ```ruby
    class SomeJob
      def self.fair_tenant(*_perform_arguments)
        # Return any string that will be used as tenant name
        "tenant_1"
      end
    end
    ```

 3. Set `fair_tenant` job option in a custom [middleware](https://github.com/sidekiq/sidekiq/wiki/Middleware) earlier in the stack.

 4. Or let this gem automatically pick tenant name from [apartment-sidekiq](https://github.com/influitive/apartment-sidekiq) if you're using apartment gem.

## Configuration

Configuration is handled by [anyway_config] gem. With it you can load settings from environment variables (which names are constructed from config key upcased and prefixed with `SIDEKIQ_FAIR_TENANT_`), YAML files, and other sources. See [anyway_config] docs for details.

| Config key                 | Type     | Default                                                             | Description                                                                                                                                                                                                             |
|----------------------------|----------|---------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `max_throttling_window`    | integer  | `86_400` (1 day)                                                    | Maximum throttling window in seconds                                                                                                                                                                                    |
| `enqueues_key`             | string   | `sidekiq-fair_tenant:enqueued:%<job_class>s:tenant:%<fair_tenant>s` | Ruby [format string](https://docs.ruby-lang.org/en/3.3/format_specifications_rdoc.html) used as a name for Redis key holding job ids for throttling window. Available placeholders: `queue`, `job_class`, `fair_tenant` |
| `logger`                   | logger   | `Sidekiq.logger`                                                    | Logger instance used for warning logging.                                                                                                                                                                               |

## How it works

If number of jobs enqueued by a single client exceeds some threshold per a sliding time window, their jobs would be re-routed to another queue, with lower priority.

This gem tracks single client's jobs in a Redis [sorted set](https://redis.io/docs/data-types/sorted-sets/) with job id as a key and enqueuing timestamp as a score. When a new job is enqueued, it is added to the set, and then the set is trimmed to contain only jobs enqueued within the last `max_throttling_window` seconds.

On every enqueue attempt, the set is checked for number of jobs enqueued within the last `per` seconds of every rule. If the number of jobs in this time window exceeds `threshold`, the job is enqueued to a throttled queue, otherwise it is enqueued to the default queue. If multiple rules match, last one is used.

You are expected to configure Sidekiq to process throttled queues with lower priority using [queue weights](https://github.com/mperham/sidekiq/wiki/Advanced-Options#queues).

### Advantages
 - If fast queues are empty then slow queues are processed at full speed (no artificial delays)
 - If fast queues are full, slow queues are still processed, but slower (configurable), so application doesn’t “stall” for throttled users
 - Minimal changes to the application code are required.

### Disadvantages
 - As Sidekiq does not support mixing ordered and weighted queue modes (as stated in Sidekiq Wiki on queue configuration), you can’t make the same worker process execute some super important queue always first, ignoring other queues. Run separate worker to solve this.
 - You have to keep track of all your queues and their weights.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Envek/sidekiq-fair_tenant.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

[sidekiq]: https://github.com/sidekiq/sidekiq "Simple, efficient background processing for Ruby"
[anyway_config]: https://github.com/palkan/anyway_config "Configuration library for Ruby gems and applications"
