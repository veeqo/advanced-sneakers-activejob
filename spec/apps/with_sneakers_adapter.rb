# frozen_string_literal: true

require 'bundler/setup'
require 'rails'
require 'active_job/railtie'
require 'action_mailer/railtie' unless ENV['SKIP_MAILER']

require 'sneakers'

class App < Rails::Application
  config.root = __dir__
  config.active_job.queue_adapter = :sneakers
  config.eager_load = true
  config.logger = Logger.new(Rails.root.join('log/rails.log'))
  config.logger.level = :debug
  config.action_mailer.delivery_method = :test unless ENV['SKIP_MAILER']
end

App.initialize!
