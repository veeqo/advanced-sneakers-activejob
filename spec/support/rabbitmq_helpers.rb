# frozen_string_literal: true

require 'rabbitmq/http/client'

module RabbitmqHelpers
  class HttpApi
    attr_reader :client, :vhost

    def initialize(amqp:, port: 15_672, scheme: 'http')
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

    def queues
      client.list_queues(vhost, columns: 'name,passive,durable,exclusive,auto_delete,arguments')
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
      @http_api ||= HttpApi.new(amqp: 'amqp://guest:guest@localhost:5672/advanced_sneakers')
    end
  end

  delegate :reset_vhost, :queues, to: :'RabbitmqHelpers.http_api', prefix: :rabbitmq
end

RSpec.configure do |config|
  config.include RabbitmqHelpers, :rabbitmq
  config.before(:each, :rabbitmq) { rabbitmq_reset_vhost }
end
