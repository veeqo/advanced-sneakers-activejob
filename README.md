# `:advanced_sneakers` adapter for ActiveJob

Drop-in replacement for `:sneakers` adapter of ActiveJob. Extra features:

1. Respects `queue_as` and translates ActiveJob `queue_name` to RabbitMQ `queue`
2. Supports custom routing_key (just define `routing_key` in your Job class)
3. Allows to run ActiveJob consumers separately from manually defined Sneakers consumers
4. [UPCOMING] Limited support for `enqueue_at` by predefined delays (e.g. `[1.second, 10.seconds, 1.minute, 1.hour]`)
5. [UPCOMING] Fallback to retries by DLX on job failure

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'advanced-sneakers-activejob'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install advanced-sneakers-activejob

## Usage

Configure ActiveJob adapter
```ruby
config.active_job.queue_adapter = :advanced_sneakers
```

Run worker
```sh
rake sneakers:active_job
```

## Configuration

```ruby
AdvancedSneakersActiveJob.configure do |config|
  # Ensure that queue & bindings exist before message published
  config.safe_publish = true

  # By default Sneakers assumes queue binding routing key matches to queue name. So safe publish assumes the same.
  config.bind_by_queue_name = true

  # Should Sneakers build-in runner (e.g. `rake sneakers:run`) run ActiveJob consumers?
  # :include - yes
  # :exclude - no
  # :only - Sneakers runner will run _only_ ActiveJob consumers
  #
  # This setting might be helpful if you want to run ActiveJob consumers apart from native Sneakers consumers.
  # In that case set strategy to :exclude and use `rake sneakers:run` for native and `rake sneakers:active_job` for ActiveJob consumers
  config.activejob_workers_strategy = :include

  # Custom sneakers configuration for ActiveJob publisher & runner
  config.sneakers = { } # actually fallbacks to Sneakers::CONFIG
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/veeqo/advanced-sneakers-activejob.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
