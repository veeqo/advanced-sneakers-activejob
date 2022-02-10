# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'bunny_publisher'

require 'sneakers'
require 'advanced_sneakers_activejob/workers_registry'
Sneakers::Worker.send(:remove_const, :Classes)
Sneakers::Worker::Classes = AdvancedSneakersActiveJob::WorkersRegistry.new

require 'advanced_sneakers_activejob/version'
require 'advanced_sneakers_activejob/content_type'
require 'advanced_sneakers_activejob/exponential_backoff'
require 'advanced_sneakers_activejob/handler'
require 'advanced_sneakers_activejob/configuration'
require 'advanced_sneakers_activejob/errors'
require 'advanced_sneakers_activejob/publisher'
require 'advanced_sneakers_activejob/delayed_publisher'
require 'advanced_sneakers_activejob/active_job_patch'
require 'advanced_sneakers_activejob/railtie' if defined?(::Rails::Railtie)
require 'active_job/queue_adapters/advanced_sneakers_adapter'

ActiveSupport.on_load(:active_job) do
  ActiveJob::Base.include AdvancedSneakersActiveJob::ActiveJobPatch
end

# Enforce definition of ActionMailer consumers
ActiveSupport.on_load(:action_mailer) do
  # https://github.com/rails/rails/commit/f5050d998def98563f8fa4b381c09f563681f159
  require 'action_mailer/mail_delivery_job' if ActionMailer.gem_version >= Gem::Version.new('6.0.0')

  # https://github.com/rails/rails/commit/ddc7fb6e6ee957aae35f1bb11d35c2d3e3b0cdda
  require 'action_mailer/delivery_job' if ActionMailer.gem_version < Gem::Version.new('7.0.0')
end

# Advanced Sneakers adapter for ActiveJob
module AdvancedSneakersActiveJob
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    def define_consumer(queue_name:)
      name = consumer_name(queue_name: queue_name)

      return const_get(name) if const_defined?(name)

      klass = Class.new(ActiveJob::QueueAdapters::AdvancedSneakersAdapter::JobWrapper)
      const_set(name, klass)
      klass.include Sneakers::Worker
      klass.from_queue(queue_name, config.sneakers)

      klass
    end

    def publisher
      @publisher ||= AdvancedSneakersActiveJob::Publisher.new(**config.publisher_config)
    end

    def delayed_publisher
      @delayed_publisher ||= AdvancedSneakersActiveJob::DelayedPublisher.new(**config.publisher_config)
    end

    # Based on ActiveSupport::Inflector#parameterize
    def consumer_name(queue_name:)
      # replace accented chars with their ascii equivalents
      parameterized_string = ::ActiveSupport::Inflector.transliterate(queue_name)
      # Turn unwanted chars into the separator
      parameterized_string.gsub!(/[^a-z0-9\-_]+/, '_')
      # No more than one of the separator in a row.
      parameterized_string.gsub!(/_{2,}/, '_')
      # Remove leading/trailing separator.
      parameterized_string.gsub!(/^_|_$/, '')
      # Ruby does not allow classes with leading digits
      parameterized_string.gsub!(/\A(\d)/, 'queue\1')

      [parameterized_string, 'consumer'].join('_').classify
    end

    def const_missing(name)
      Sneakers::Worker::Classes.define_active_job_consumers

      constants.include?(name) ? const_get(name) : super
    end
  end
end
