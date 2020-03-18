# frozen_string_literal: true

module AdvancedSneakersActiveJob
  # Advanced Sneakers adapter allows to patch Sneakers with custom configuration.
  # It is useful when already have Sneakers workers running and you want to run ActiveJob Sneakers process with another options.
  class Configuration
    include ActiveSupport::Configurable

    DEFAULT_SNEAKERS_CONFIG = {
      exchange: 'activejob'
    }.freeze

    config_accessor(:handle_unrouted_messages) { true } # create queue/binding and re-publish if message is unrouted
    config_accessor(:activejob_workers_strategy) { :include } # [:include, :exclude, :only]
    config_accessor(:delay_proc) { ->(timestamp) { (timestamp - Time.now.to_f).round } } # seconds
    config_accessor(:delayed_queue_prefix) { 'delayed' }

    def sneakers
      Sneakers::CONFIG.to_hash.deep_merge(DEFAULT_SNEAKERS_CONFIG.deep_merge(config.sneakers || {}))
    end

    def sneakers=(custom)
      config.sneakers = custom
    end
  end
end
