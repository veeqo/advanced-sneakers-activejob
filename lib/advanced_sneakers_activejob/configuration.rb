# frozen_string_literal: true

module AdvancedSneakersActiveJob
  # Advanced Sneakers adapter allows to patch Sneakers with custom configuration.
  # It is useful when already have Sneakers workers running and you want to run ActiveJob Sneakers process with another options.
  class Configuration
    include ActiveSupport::Configurable

    DEFAULT_SNEAKERS_CONFIG = {
      exchange: 'activejob',
      handler: AdvancedSneakersActiveJob::Handler
    }.freeze

    config_accessor(:handle_unrouted_messages) { true } # create queue/binding and re-publish if message is unrouted
    config_accessor(:activejob_workers_strategy) { :include } # [:include, :exclude, :only]
    config_accessor(:delay_proc) { ->(timestamp) { (timestamp - Time.now.to_f).round } } # seconds
    config_accessor(:delayed_queue_prefix) { 'delayed' }
    config_accessor(:delayed_queue_options) { { 'x-queue-mode' => 'lazy' } }
    config_accessor(:retry_delay_proc) { ->(count) { AdvancedSneakersActiveJob::EXPONENTIAL_BACKOFF[count] } } # seconds
    config_accessor(:log_level) { :info } # debug logs are too noizy because of Bunny

    config_accessor(:publish_connection)

    def republish_connection=(_)
      ActiveSupport::Deprecation.warn('Republish connection is not used for bunny-publisher v0.2+')
    end

    def sneakers
      custom_config = DEFAULT_SNEAKERS_CONFIG.deep_merge(config.sneakers || {})

      if custom_config[:amqp].present? & custom_config[:vhost].nil?
        custom_config[:vhost] = AMQ::Settings.parse_amqp_url(custom_config[:amqp]).fetch(:vhost, '/')
      end

      Sneakers::CONFIG.to_hash.deep_merge(custom_config)
    end

    def sneakers=(custom)
      config.sneakers = custom
    end

    def publisher_config
      sneakers.merge(publish_connection: publish_connection)
    end
  end
end
