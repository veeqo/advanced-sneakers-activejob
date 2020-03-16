# `:advanced_sneakers` adapter for ActiveJob [![Build Status](https://travis-ci.com/veeqo/advanced-sneakers-activejob.svg?branch=master)](https://travis-ci.com/veeqo/advanced-sneakers-activejob)

Drop-in replacement for `:sneakers` adapter of ActiveJob. Extra features:

1. Creates queue & binding on publishing to ensure that message won't be lost (see `safe_publish` in [configuration](#configuration))
2. Respects `queue_as` of ActiveJob and uses correspondent RabbitMQ `queue` for consumers
3. Supports [custom routing keys](#custom-routing-keys)
4. Allows to run ActiveJob consumers [separately](#how-to-separate-activejob-consumers) from manually defined Sneakers consumers
5. [UPCOMING] Fallback to retries by DLX on job failure
6. [UPCOMING] Limited support for `enqueue_at` by predefined delays (e.g. `[1.second, 10.seconds, 1.minute, 1.hour]`)

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
  # Ensure that queue & binding exist before message published.
  # By default Sneakers assumes queue binding routing key matches to queue name. So safe publish assumes the same.
  # Safe publishing works only if job doesn't have custom routing key.
  config.safe_publish = true

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

## Custom routing keys

Advanced sneakers adapter supports customizable [routing keys](https://www.rabbitmq.com/tutorials/tutorial-four-ruby.html).

```ruby
class MyJob < ActiveJob::Base

  queue_as :some_name

  def perform(params)
    # ProcessData.new(params).call
  end

  def routing_key
    # we have instance of job here (including #arguments)
    'my.custom.routing.key'
  end
end
```

Take into accout that custom **routing key is used for publishing only**. Consumers are not aware about it. Ensure you have proper bindings before publishing or you might lose your messages.

## How to separate ActiveJob consumers

Sneakers comes with `rake sneakers:run` task, which would run all consumers (including ActiveJob ones). If you need to run native sneakers consumers apart from ActiveJob consumers:
1. Set `activejob_workers_strategy` to `:exclude` in [configuration](#configuration)
2. Run `rake sneakers:run` task to run native Sneakers consumers
3. Run `rake sneakers:active_job` task to run ActiveJob consumers


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/veeqo/advanced-sneakers-activejob.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
