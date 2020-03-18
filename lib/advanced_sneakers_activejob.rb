# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'

require 'sneakers'
require 'advanced_sneakers_activejob/workers_registry'
Sneakers::Worker.send(:remove_const, :Classes)
Sneakers::Worker::Classes = AdvancedSneakersActiveJob::WorkersRegistry.new

require 'advanced_sneakers_activejob/version'
require 'advanced_sneakers_activejob/content_type'
require 'advanced_sneakers_activejob/configuration'
require 'advanced_sneakers_activejob/errors'
require 'advanced_sneakers_activejob/publisher'
require 'advanced_sneakers_activejob/active_job_patch'
require 'advanced_sneakers_activejob/railtie' if defined?(::Rails::Railtie)
require 'active_job/queue_adapters/advanced_sneakers_adapter'

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
      @consumers ||= {}

      @consumers[queue_name] ||= begin
        klass = Class.new(ActiveJob::QueueAdapters::AdvancedSneakersAdapter::JobWrapper)
        klass.include Sneakers::Worker
        const_set([queue_name, 'queue_consumer'].join('_').classify, klass)
        klass.from_queue(queue_name, AdvancedSneakersActiveJob.config.sneakers)
      end
    end
  end
end
