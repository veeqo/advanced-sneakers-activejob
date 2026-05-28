# frozen_string_literal: true

require 'rabbitmq/http/client'

module RabbitmqHelpers
  class HttpApi
    attr_reader :client, :vhost

    def initialize(amqp: ENV.fetch('RABBITMQ_URL'), port: ENV.fetch('RABBITMQ_HTTP_PORT', 15_672).to_i, scheme: ENV.fetch('RABBITMQ_HTTP_SCHEME', 'http'))
      uri = URI(amqp)
      @vhost = uri.path[%r{/([^/]+)}, 1]

      raise ArgumentError, 'Default vhost is not supported for tests' if vhost.blank?

      uri.scheme = scheme
      uri.port = port
      uri.path = '/'

      @client = RabbitMQ::HTTP::Client.new(uri.to_s)
    end

    def reset_vhost
      delete_vhost
      create_vhost
    end

    def queues(columns: %w[name passive durable exclusive auto_delete arguments])
      client.list_queues(vhost, columns: columns.join(',')).map do |queue|
        queue['arguments'].delete('x-queue-type') if queue['arguments']
        queue
      end
    end

    def messages(queue, ackmode: 'ack_requeue_true', count: 1, encoding: 'auto')
      client.get_messages(vhost, queue, ackmode: ackmode, count: count, encoding: encoding)
    end

    def bindings(queue:, exchange: 'sneakers')
      client.list_bindings_between_queue_and_exchange(vhost, queue, exchange)
    end

    def delete_all_queues
      queues_list = client.list_queues(vhost)
      queues_list.each { |queue| client.delete_queue(vhost, queue['name']) }
    rescue Faraday::ResourceNotFound
      client.create_vhost(vhost)
    end

    private

    def create_vhost
      client.create_vhost(vhost)
    end

    def delete_vhost
      client.delete_vhost(vhost)
    rescue Faraday::ResourceNotFound
      # it is normal
    end
  end

  class << self
    def http_api
      @http_api ||= HttpApi.new
    end
  end

  delegate :reset_vhost, :queues, :messages, :bindings, :delete_all_queues, to: :'RabbitmqHelpers.http_api', prefix: :rabbitmq
end

RSpec.configure do |config|
  config.include RabbitmqHelpers, :rabbitmq

  config.before(:each, :rabbitmq) { rabbitmq_delete_all_queues }
end
