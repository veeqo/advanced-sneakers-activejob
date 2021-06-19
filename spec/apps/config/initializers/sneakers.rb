# frozen_string_literal: true

Sneakers.configure amqp: ENV.fetch('RABBITMQ_URL'),
                   daemonize: true,
                   log: Rails.root.join('log/sneakers.log')
