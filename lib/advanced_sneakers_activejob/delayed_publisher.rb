# frozen_string_literal: true

module AdvancedSneakersActiveJob
  # This publisher relies on TTL to keep messages in a queue.
  # When TTL is reached, messages go to another exchange (see dlx_exchange_name param).
  class DelayedPublisher < ::BunnyPublisher::Base
    include ::BunnyPublisher::Mandatory

    delegate :logger, to: :'::ActiveJob::Base'

    delegate :name_prefix, :delayed_queue_prefix,
             to: :'AdvancedSneakersActiveJob.config',
             prefix: :config

    before_publish :log_message

    attr_reader :dlx_exchange_name

    def initialize(exchange:, **options)
      super(**options.merge(exchange: [exchange, 'delayed'].join('-'), exchange_options: { type: 'headers', durable: true }))

      @dlx_exchange_name = exchange
    end

    private

    def log_message
      logger.debug do
        "Publishing <#{message}> to [#{@exchange_name}] with routing_key [#{message_options[:routing_key]}] and delay [#{delay}]"
      end
    end

    def declare_republish_queue
      queue_name = delayed_queue_name(delay: delay)

      queue_arguments = {
        'x-queue-mode' => 'lazy', # tell RabbitMQ not to use RAM for this queue as it won't be consumed
        'x-message-ttl' => delay * 1000, # make messages die after requested time
        'x-dead-letter-exchange' => dlx_exchange_name # dead messages go to original exchange and then routed to proper queues
      }

      logger.debug { "Creating delayed queue [#{queue_name}]" }

      channel.queue(queue_name, durable: true, arguments: queue_arguments)
    end

    def delay
      message_options.dig(:headers, 'delay')
    end

    def declare_republish_queue_binding(queue)
      queue.bind(exchange, arguments: { delay: delay })
    end

    def delayed_queue_name(delay:)
      [
        ::ActiveJob::Base.queue_name_prefix,
        [config_delayed_queue_prefix, delay].join(':')
      ].compact.join(::ActiveJob::Base.queue_name_delimiter)
    end
  end
end
