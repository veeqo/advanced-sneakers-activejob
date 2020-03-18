# frozen_string_literal: true

module AdvancedSneakersActiveJob
  # Based on Sneakers::Publisher, but refactored to utilize :mandatory option to handle unrouted messages
  # http://rubybunny.info/articles/exchanges.html#publishing_messages_as_mandatory
  class Publisher
    WAIT_FOR_UNROUTED_MESSAGES_AT_EXIT_TIMEOUT = 30

    delegate :sneakers, :handle_unrouted_messages, :delayed_queue_prefix,
             to: :'AdvancedSneakersActiveJob.config', prefix: :config

    delegate :logger, to: :'ActiveJob::Base'

    attr_reader :publish_channel, :republish_channel,
                :publish_exchange, :republish_exchange,
                :publish_delayed_exchange, :republish_delayed_exchange

    def initialize
      @mutex = Mutex.new
      at_exit { wait_for_unrouted_messages_processing(timeout: WAIT_FOR_UNROUTED_MESSAGES_AT_EXIT_TIMEOUT) }
    end

    def publish(message, routing_key:, headers: {}, properties: {})
      ensure_connection!

      logger.debug "Publishing <#{message}> to [#{publish_exchange.name}] with routing_key [#{routing_key}]"

      params = properties.merge(
        routing_key: routing_key,
        mandatory: true,
        content_type: AdvancedSneakersActiveJob::CONTENT_TYPE,
        headers: headers
      )

      publish_exchange.publish(message, params)
    end

    def publish_delayed(message, routing_key:, delay:, headers: {}, properties: {})
      ensure_connection!

      logger.debug "Publishing <#{message}> to [#{publish_delayed_exchange.name}] with routing_key [#{routing_key}] and delay [#{delay}]"

      params = properties.merge(
        routing_key: routing_key,
        mandatory: true,
        content_type: AdvancedSneakersActiveJob::CONTENT_TYPE,
        headers: headers.merge(delay: delay.to_i) # do not use x- prefix because headers exchanges ignore such headers
      )

      publish_delayed_exchange.publish(message, params)
    end

    private

    def ensure_connection!
      @mutex.synchronize do
        unless connected?
          start_connections!
          create_channels!
          configure_exchanges!
        end
      end
    end

    def start_connections!
      @publish_connection ||= create_bunny_connection
      @publish_connection.start

      @republish_connection ||= create_bunny_connection
      @republish_connection.start
    end

    def create_channels!
      @publish_channel = @publish_connection.create_channel
      @republish_channel = @republish_connection.create_channel
    end

    def configure_exchanges!
      @publish_exchange = build_exchange(@publish_channel)
      @publish_exchange.on_return { |*attrs| handle_unrouted_messages(*attrs) }

      @publish_delayed_exchange = build_delayed_exchange(@publish_channel)
      @publish_delayed_exchange.on_return { |*attrs| handle_unrouted_delayed_messages(*attrs) }

      @republish_exchange = build_exchange(republish_channel)
      @republish_delayed_exchange = build_delayed_exchange(republish_channel)
    end

    def connected?
      @publish_connection&.connected? &&
        @republish_connection&.connected? &&
        @publish_channel &&
        @republish_channel
    end

    # Returned messages are processed asynchronously and there is a probability for messages loses on program exit or network failure.
    # Second connection is required because `on_return` is called within a frameset of amqp connection.
    # Any interaction within the connection (even by another channel) can lead to connection error.
    # https://github.com/ruby-amqp/bunny/blob/7fb05abf36637557f75a69790be78f9cc1cea807/lib/bunny/session.rb#L683
    def handle_unrouted_messages(return_info, properties, message)
      @unrouted_message = true

      params = { message: message, return_info: return_info, properties: properties }

      raise(PublishError, params) if return_info.reply_code != 312 # NO_ROUTE

      if config_handle_unrouted_messages
        setup_routing_and_republish_message(params)
      else
        logger.warn("Message is not routed! #{params}")
      end

      @unrouted_message = false
    end

    def handle_unrouted_delayed_messages(return_info, properties, message)
      @unrouted_delayed_message = true

      params = { message: message, return_info: return_info, properties: properties }

      raise(PublishError, params) if return_info.reply_code != 312 # NO_ROUTE

      setup_routing_and_republish_delayed_message(params)

      @unrouted_delayed_message = false
    end

    # TODO: introduce more reliable way to wait for handling of unrouted messages at exit
    def wait_for_unrouted_messages_processing(timeout:)
      sleep(0.05) # gives publish_exchange some time to receive retuned message

      return unless @unrouted_message || @unrouted_delayed_message

      logger.warn("Waiting up to #{timeout} seconds for unrouted messages handling")

      Timeout.timeout(timeout) { sleep 0.01 while @unrouted_message || @unrouted_delayed_message }
    rescue Timeout::Error
      logger.warn('Some unrouted messages are lost on process exit!')
    end

    def setup_routing_and_republish_message(message:, return_info:, properties:)
      logger.debug("Performing queue/binding setup & re-publish for unrouted message. #{{ message: message, return_info: return_info }}")

      routing_key = return_info.routing_key

      create_queue_and_binding(queue_name: deserialize(message).fetch('queue_name'), routing_key: routing_key)

      logger.debug "Re-publishing <#{message}> to [#{republish_exchange.name}] with routing_key [#{routing_key}]"
      republish_exchange.publish(message, properties.to_h.merge(routing_key: routing_key))
    end

    def create_queue_and_binding(queue_name:, routing_key:)
      logger.debug "Creating queue [#{queue_name}] and binding with routing_key [#{routing_key}] to [#{republish_exchange.name}]"
      republish_channel.queue(queue_name, config_sneakers[:queue_options]).tap do |queue|
        queue.bind(republish_exchange, routing_key: routing_key)
        republish_channel.deregister_queue(queue) # we are not going to work with this queue in this channel
      end
    end

    def setup_routing_and_republish_delayed_message(message:, return_info:, properties:)
      delay = properties.headers.fetch('delay').to_i
      queue_name = delayed_queue_name(delay: delay)

      logger.debug "Creating delayed queue [#{queue_name}]"

      create_delayed_queue_and_binding(queue_name: queue_name, delay: delay)

      republish_delayed_exchange.publish message, properties.to_h.merge(routing_key: return_info.routing_key)
    end

    def delayed_queue_name(delay:)
      [
        config_delayed_queue_prefix,
        delay
      ].join(':')
    end

    def create_delayed_queue_and_binding(queue_name:, delay:)
      queue_arguments = {
        'x-queue-mode' => 'lazy', # tell RabbitMQ not to use RAM for this queue as it won't be consumed
        'x-message-ttl' => delay * 1000, # make messages die after requested time
        'x-dead-letter-exchange' => republish_exchange.name # died messages go to original exchange and then routed to consumers
      }

      republish_channel.queue(queue_name, durable: true, arguments: queue_arguments).tap do |queue|
        queue.bind(republish_delayed_exchange, arguments: { delay: delay })
        republish_channel.deregister_queue(queue) # we are not going to work with this queue in this channel
      end
    end

    def build_exchange(channel)
      channel.exchange(config_sneakers[:exchange], config_sneakers[:exchange_options])
    end

    def build_delayed_exchange(channel)
      channel.exchange([config_sneakers[:exchange], 'delayed'].join('-'), type: 'headers', durable: true)
    end

    def create_bunny_connection
      Bunny.new config_sneakers[:amqp],
                vhost: config_sneakers[:vhost],
                heartbeat: config_sneakers[:heartbeat],
                properties: config_sneakers.fetch(:properties, {})
    end

    def deserialize(message)
      Sneakers::ContentType.deserialize(message, AdvancedSneakersActiveJob::CONTENT_TYPE)
    end
  end
end
