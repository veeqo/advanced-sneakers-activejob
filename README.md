# `:advanced_sneakers` adapter for ActiveJob
[![Build Status](https://github.com/veeqo/advanced-sneakers-activejob/actions/workflows/main.yml/badge.svg?branch=master)](https://github.com/veeqo/advanced-sneakers-activejob/actions/workflows/main.yml) [![Gem Version](https://badge.fury.io/rb/advanced-sneakers-activejob.svg)](https://badge.fury.io/rb/advanced-sneakers-activejob)

Drop-in replacement for `:sneakers` adapter of ActiveJob. Extra features:

1. Tries to [handle unrouted messages](#unrouted-messages)
2. Respects `queue_as` of ActiveJob and defines consumer class per RabbitMQ queue
3. Supports [custom message options](#custom-message-options)
4. Allows to run ActiveJob consumers [separately](#how-to-separate-activejob-consumers) from native Sneakers consumers
5. Support for [`delayed jobs`](https://edgeguides.rubyonrails.org/active_job_basics.html#enqueue-the-job) `GuestsCleanupJob.set(wait: 1.week).perform_later(guest)`
6. [Exponential backoff\*](#exponential-backoff)
7. Exposes [`#delivery_info` & `#headers`](#amqp-metadata) AMQP metadata to job

<p align="center">
  <a href="https://www.veeqo.com/" title="Sponsored by Veeqo">
    <img src="https://static.veeqo.com/assets/sponsored_by_veeqo.png" width="360" />
  </a>
</p>

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

[Configure ActiveJob adapter](https://edgeguides.rubyonrails.org/active_job_basics.html#setting-the-backend)
```ruby
config.active_job.queue_adapter = :advanced_sneakers
```

Run worker for all queues of ActiveJob
```sh
rake sneakers:active_job
```

Run worker for picked queues of ActiveJob
```sh
QUEUES=mailers,foo,bar rake sneakers:active_job
```

Wildcards are supported for queues names with "words" (separator is `.`). Algorithm is similar to the way the [topic exchange matches routing keys](https://www.rabbitmq.com/tutorials/tutorial-five-python.html). `*` (star) substitutes for exactly one word. `#` (hash) substitutes for zero or more words

```sh
QUEUES=mailers,index.*,telemetery.# rake sneakers:active_job
```

## Unrouted messages

If message is published before routing has been configured (e.g. by consumer), it might be lost. To mitigate this problem the adapter uses [:mandatory](http://rubybunny.info/articles/exchanges.html#publishing_messages_as_mandatory) option for publishing messages. RabbitMQ returns unrouted messages back and the publisher is able to handle them:

1. Create queue
2. Create binding
3. Re-publish message

There is a setting `handle_unrouted_messages` in [configuration](#configuration) to disable this behavior. If it is disabled, publisher will only log unrouted messages.

Take into accout that **this process is asynchronous**. It means that in case of network failures or process exit unrouted messages could be lost. The adapter tries to postpone application exit up to 5 seconds in case if there are unrouted messages, but it does not provide any guarantees.

**Delayed messages are not handled!** If job is delayed `GuestsCleanupJob.set(wait: 1.week).perform_later(guest)` and there is no proper routing defined at the moment of job execution, it would be lost.

## Custom message options

Advanced sneakers adapter allows to set [custom message options](http://reference.rubybunny.info/Bunny/Exchange.html#publish-instance_method) (e.g. [routing keys](https://www.rabbitmq.com/tutorials/tutorial-four-ruby.html)) on class-level.

```ruby
class MyJob < ActiveJob::Base

  queue_as :some_name

  message_options routing_key: 'my.custom.routing.key',
                  headers: { 'foo' => 'bar' }

  def perform(params)
    # ProcessData.new(params).call
  end
end
```

Procs are also supported
```ruby
class MyJob < ActiveJob::Base

  queue_as :some_name

  message_options routing_key: ->(job) { "process_user_data.#{job.arguments.first.vip? ? 'urgent' : 'regular' }" }

  def perform(user)
    # ProcessUserData.new(user).call
  end
end
```

And also supports custom message options per job
```ruby
MyJob.set(priority: 1, headers: { 'foo' => 'bar' }).perform_later('baz')
```

Read more about message properties:
- https://www.rabbitmq.com/publishers.html#message-properties
- http://reference.rubybunny.info/Bunny/Exchange.html#publish-instance_method

Take into accout that **custom message options are used for publishing only**.

## How to separate ActiveJob consumers

Sneakers comes with `rake sneakers:run` task, which would run all consumers (including ActiveJob ones). If you need to run native sneakers consumers apart from ActiveJob consumers:
1. Set `activejob_workers_strategy` to `:exclude` in [configuration](#configuration)
2. Run `rake sneakers:run` task to run native Sneakers consumers
3. Run `rake sneakers:active_job` task to run ActiveJob consumers

Tip: if you want to see how consumers are grouped, exec `Sneakers::Worker::Classes` in rails console.

## Exponential backoff\*

The adapter enforces `AdvancedSneakersActiveJob::Handler` for ActiveJob consumers. This handler applies [exponential backoff](https://en.wikipedia.org/wiki/Exponential_backoff) if failure is not handled by ActiveJob [`rescue_from`/`retry_on`/`discard_on`](https://edgeguides.rubyonrails.org/active_job_basics.html#retrying-or-discarding-failed-jobs).
Error name is tracked in `x-last-error-name`, error full message is tracked in `x-last-error-details` gzipped & encoded by Base64. To decode error details:

```ruby
ActiveSupport::Gzip.decompress(Base64.decode64(data_from_header))
```

\* For RabbitMQ queues amount optimization exponential backoff is not calculated by formula, but predifined. You can customize `retry_delay_proc` in [configuration](#configuration)

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
  # Delayed unrouted messages are not handled.
  config.handle_unrouted_messages = true

  # Should Sneakers build-in runner (e.g. `rake sneakers:run`) run ActiveJob consumers?
  # :include - yes
  # :exclude - no
  # :only - Sneakers runner will run _only_ ActiveJob consumers
  #
  # This setting might be helpful if you want to run ActiveJob consumers apart from native Sneakers consumers.
  # In that case set strategy to :exclude and use `rake sneakers:run` for native and `rake sneakers:active_job` for ActiveJob consumers
  config.activejob_workers_strategy = :include

  # All delayed messages delays are rounded to seconds.
  config.delay_proc = ->(timestamp) { (timestamp - Time.now.to_f).round } } # integer result is expected

  # Delayed queues can be filtered by this prefix (e.g. delayed:60 - queue for messages with 1 minute delay)
  config.delayed_queue_prefix = 'delayed'

  # Custom sneakers configuration for ActiveJob publisher & runner
  config.sneakers = {
    connection: Bunny.new('CUSTOM_URL', with: { other: 'options' }),
    exchange: 'activejob',
    handler: AdvancedSneakersActiveJob::Handler
  }

  # Define custom delay for retries, but remember - each unique delay leads to new queue on RabbitMQ side
  config.retry_delay_proc = ->(count) { AdvancedSneakersActiveJob::EXPONENTIAL_BACKOFF[count] }

  # Connection for publisher (fallbacks to connection of consumers)
  config.publish_connection = Bunny.new('CUSTOM_URL', with: { other: 'options' })
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/veeqo/advanced-sneakers-activejob.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## About [Veeqo](https://www.veeqo.com)

At Veeqo, our team of Engineers is on a mission to create a world-class Inventory and Shipping platform, built to the highest standards in best coding practices. We are a growing team, looking for other passionate developers to [join us](https://veeqo-ltd.breezy.hr/) on our journey. If you're looking for a career working for one of the most exciting tech companies in ecommerce, we want to hear from you.

[Veeqo developers blog](https://devs.veeqo.com)
