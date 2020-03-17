# `:advanced_sneakers` adapter for ActiveJob [![Build Status](https://travis-ci.com/veeqo/advanced-sneakers-activejob.svg?branch=master)](https://travis-ci.com/veeqo/advanced-sneakers-activejob)

Drop-in replacement for `:sneakers` adapter of ActiveJob. Extra features:

1. Tries to [handle unrouted messages](#unrouted-messages)
2. Respects `queue_as` of ActiveJob and uses correspondent RabbitMQ `queue` for consumers
3. Supports [custom routing keys](#custom-routing-keys)
4. Allows to run ActiveJob consumers [separately](#how-to-separate-activejob-consumers) from manually defined Sneakers consumers
5. [UPCOMING] Support for `enqueue_at`
6. [UPCOMING] Fallback to retries by DLX on job failure
7. [Exposes `#delivery_info` & `#headers`](#amqp-metadata) AMQP metadata to job

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

## Unrouted messages

If message is published before routing has been configured (e.g. by consumer), it might be lost. To mitigate this problem the adapter uses [:mandatory](http://rubybunny.info/articles/exchanges.html#publishing_messages_as_mandatory) option for publishing messages. RabbitMQ returns unrouted messages back and the publisher is able to handle them:

1. Create queue
2. Create binding
3. Re-publish message

There is a setting `handle_unrouted_messages` in [configuration](#configuration) to disable this behavior. If it is disabled, publisher will only log unrouted messages.

Take into accout that **this process is asynchronous**. It means that in case of network failures or process exit unrouted messages could be lost. Adapter tries to postpone application exit up to 30 seconds in case if there are unrouted messages, but it does not provide any guarantees.

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

Take into accout that **custom routing key is used for publishing only**.

## How to separate ActiveJob consumers

Sneakers comes with `rake sneakers:run` task, which would run all consumers (including ActiveJob ones). If you need to run native sneakers consumers apart from ActiveJob consumers:
1. Set `activejob_workers_strategy` to `:exclude` in [configuration](#configuration)
2. Run `rake sneakers:run` task to run native Sneakers consumers
3. Run `rake sneakers:active_job` task to run ActiveJob consumers


## AMQP metadata

Each message in AMQP comes with `delivery_info` and `headers`. `:advanced_sneakers` adapter provides them on job level.

```ruby
class SomeComplexJob < ActiveJob::Base
  before :perform do |job|
    # metadata is available in callbacks
    logger.debug({delivery_info: job.delivery_info, headers: job.headers})
  end

  def perform(msg)
    # metadata is available here as well
    logger.debug({delivery_info: delivery_info, headers: headers})
  end
end
```

## Configuration

```ruby
AdvancedSneakersActiveJob.configure do |config|
  # Should AdvancedSneakersActiveJob try to handle unrouted messages?
  # There are still no guarantees that unrouted message is not lost in case of network failure or process exit.
  config.handle_unrouted_messages = true

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
