# frozen_string_literal: true

module AdvancedSneakersActiveJob
  # Based on Sneakers::Publisher, but refactored to utilize :mandatory option to handle unrouted messages
  # http://rubybunny.info/articles/exchanges.html#publishing_messages_as_mandatory
  class Publisher
    WAIT_FOR_UNROUTED_MESSAGES_AT_EXIT_TIMEOUT = 30

    delegate :sneakers, :handle_unrouted_messages, to: :'AdvancedSneakersActiveJob.config', prefix: :config
    delegate :logger, to: :'ActiveJob::Base'

    attr_reader :publish_exchange, :republish_exchange

    def initialize
      @mutex = Mutex.new
      at_exit { wait_for_unrouted_messages_processing(timeout: WAIT_FOR_UNROUTED_MESSAGES_AT_EXIT_TIMEOUT) }
    end

    def publish(message, routing_key:)
      ensure_connection!

      logger.debug "Publishing <#{message}> to [#{publish_exchange.name}] with routing_key [#{routing_key}]"

      publish_exchange.publish message,
                               routing_key: routing_key,
                               mandatory: true,
                               content_type: AdvancedSneakersActiveJob::CONTENT_TYPE
    end

    private

    def ensure_connection!
      @mutex.synchronize do
        connect! unless connected?
      end
    end

    def connect!
      @publish_connection ||= create_bunny_connection
      @publish_connection.start

      @republish_connection ||= create_bunny_connection
      @republish_connection.start

      @publish_channel = @publish_connection.create_channel
      @publish_exchange = build_exchange(@publish_channel)
      @publish_exchange.on_return { |*attrs| handle_unrouted_messages(*attrs) }

      @republish_channel = @republish_connection.create_channel
      @republish_exchange = build_exchange(@republish_channel)
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

    # TODO: introduce more reliable way to wait for handling of unrouted messages at exit
    def wait_for_unrouted_messages_processing(timeout:)
      sleep(0.05) # gives publish_exchange some time to receive retuned message

      return unless @unrouted_message

      logger.warn("Waiting up to #{timeout} seconds for unrouted messages handling")

      Timeout.timeout(timeout) { sleep 0.01 while @unrouted_message }
    rescue Timeout::Error
      logger.warn('Some unrouted messages are lost on process exit!')
    end

    def setup_routing_and_republish_message(message:, return_info:, **_)
      logger.debug("Performing queue/binding setup & re-publish for unrouted message. #{{ message: message, return_info: return_info }}")

      routing_key = return_info.routing_key

      create_queue_and_binding(queue_name: deserialize(message).fetch('queue_name'), routing_key: routing_key)

      logger.debug "Re-publishing <#{message}> to [#{republish_exchange.name}] with routing_key [#{routing_key}]"
      republish_exchange.publish(message, routing_key: routing_key, content_type: AdvancedSneakersActiveJob::CONTENT_TYPE)
    end

    def create_queue_and_binding(queue_name:, routing_key:)
      logger.debug "Creating queue [#{queue_name}] and binding with routing_key [#{routing_key}] to [#{republish_exchange.name}]"
      @republish_channel.queue(queue_name, config_sneakers[:queue_options]).tap do |queue|
        queue.bind(republish_exchange, routing_key: routing_key)
        @republish_channel.deregister_queue(queue) # we are not going to work with this queue in this channel
      end
    end

    def build_exchange(channel)
      channel.exchange(config_sneakers[:exchange], config_sneakers[:exchange_options])
    end

    def create_bunny_connection
      Bunny.new config_sneakers[:amqp],
                vhost: config_sneakers[:vhost],
                heartbeat: config_sneakers[:heartbeat],
                properties: config_sneakers.fetch(:properties, {})
    end

    def serialize(job)
      Sneakers::ContentType.serialize(job.serialize, AdvancedSneakersActiveJob::CONTENT_TYPE)
    end

    def deserialize(message)
      Sneakers::ContentType.deserialize(message, AdvancedSneakersActiveJob::CONTENT_TYPE)
    end
  end
end
