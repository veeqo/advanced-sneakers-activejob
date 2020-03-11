# frozen_string_literal: true

require 'sneakers'
require 'active_job'

require 'advanced_sneakers_activejob/workers_registry'
Sneakers::Worker.send(:remove_const, :Classes)
Sneakers::Worker::Classes = AdvancedSneakersActiveJob::WorkersRegistry.new

require 'advanced_sneakers_activejob/version'
require 'advanced_sneakers_activejob/configuration'
require 'advanced_sneakers_activejob/consumer'
require 'advanced_sneakers_activejob/railtie' if defined?(::Rails::Railtie)

require 'active_job/queue_adapters/advanced_sneakers_adapter'
ActiveJob::Base.singleton_class.prepend(AdvancedSneakersActiveJob::Consumer)

# Advanced Sneakers adapter for ActiveJob
module AdvancedSneakersActiveJob
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end
  end
end
