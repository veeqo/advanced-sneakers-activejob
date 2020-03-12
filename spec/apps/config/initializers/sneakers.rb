# frozen_string_literal: true

Sneakers.configure amqp: 'amqp://guest:guest@localhost:5672/advanced_sneakers',
                   daemonize: true,
                   log: Rails.root.join('log/sneakers.log')
