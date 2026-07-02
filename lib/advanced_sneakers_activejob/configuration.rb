# frozen_string_literal: true

module AdvancedSneakersActiveJob
  # Advanced Sneakers adapter allows to patch Sneakers with custom configuration.
  # It is useful when already have Sneakers workers running and you want to run ActiveJob Sneakers process with another options.
  class Configuration
    DEFAULT_SNEAKERS_CONFIG = {
      exchange: 'activejob',
      handler: AdvancedSneakersActiveJob::Handler
    }.freeze

    class_attribute :handle_unrouted_messages, default: true # create queue/binding and re-publish if message is unrouted
    class_attribute :activejob_workers_strategy, default: :include # [:include, :exclude, :only]
    class_attribute :delay_proc, default: ->(timestamp) { (timestamp - Time.now.to_f).round } # seconds
    class_attribute :delayed_queue_prefix, default: 'delayed'
    class_attribute :retry_delay_proc, default: ->(count) { AdvancedSneakersActiveJob::EXPONENTIAL_BACKOFF[count] } # seconds
    class_attribute :log_level, default: :info # debug logs are too noizy because of Bunny

    class_attribute :publish_connection, default: nil

    class_attribute :sneakers_config, default: {}

    def republish_connection=(_)
      ActiveSupport::Deprecation.warn('Republish connection is not used for bunny-publisher v0.2+')
    end

    def sneakers
      custom_config = DEFAULT_SNEAKERS_CONFIG.deep_merge(sneakers_config || {})

      if custom_config[:amqp].present? & custom_config[:vhost].nil?
        custom_config[:vhost] = AMQ::Settings.parse_amqp_url(custom_config[:amqp]).fetch(:vhost, '/')
      end

      Sneakers::CONFIG.to_hash.deep_merge(custom_config)
    end

    def sneakers=(custom)
      self.sneakers_config = custom
    end

    def publisher_config
      sneakers.merge(publish_connection: publish_connection)
    end
  end
end
