# frozen_string_literal: true

require 'bundler/setup'
require 'rails'
require 'active_job/railtie'
require 'action_mailer/railtie' unless ENV['SKIP_MAILER']

$LOAD_PATH.unshift File.expand_path('../../../lib', __dir__)
require 'advanced/sneakers/activejob'

class App < Rails::Application
  config.root = __dir__
  config.active_job.queue_adapter = :inline
  config.active_job.queue_name_prefix = ENV['ACTIVE_JOB_QUEUE_NAME_PREFIX'] if ENV['ACTIVE_JOB_QUEUE_NAME_PREFIX']
  config.active_job.queue_name_delimiter = ENV['ACTIVE_JOB_QUEUE_NAME_DELIMITER'] if ENV['ACTIVE_JOB_QUEUE_NAME_DELIMITER']
  config.eager_load = true
  config.logger = Logger.new(Rails.root.join('log/rails.log'))
  config.logger.level = :debug
  config.action_mailer.delivery_method = :test unless ENV['SKIP_MAILER']
end

App.initialize!
