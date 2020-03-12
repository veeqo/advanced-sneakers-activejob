# frozen_string_literal: true

require 'bundler/setup'
require 'rails'
require 'active_job/railtie'
require 'action_mailer/railtie' unless ENV['SKIP_MAILER']

$LOAD_PATH.unshift File.expand_path('../../../lib', __dir__)
require 'advanced/sneakers/activejob'

class App < Rails::Application
  config.root = __dir__
  config.active_job.queue_adapter = :advanced_sneakers
  config.eager_load = true
  config.logger = Logger.new(Rails.root.join('log/rails.log'))
  config.logger.level = :debug
end

App.initialize!
