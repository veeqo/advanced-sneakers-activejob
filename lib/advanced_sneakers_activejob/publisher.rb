# frozen_string_literal: true

module AdvancedSneakersActiveJob
  class Publisher < ::BunnyPublisher::Base
    include ::BunnyPublisher::Mandatory

    before_publish :log_message

    delegate :logger, to: :'::ActiveJob::Base'

    delegate :handle_unrouted_messages,
             to: :'AdvancedSneakersActiveJob.config',
             prefix: :config

    private

    def log_message(publisher, message, options = {})
      logger.debug do
        "Publishing <#{message}> to [#{publisher.exchange.name}] with routing_key [#{options[:routing_key]}]"
      end
    end

    def on_message_return(return_info, properties, message)
      if config_handle_unrouted_messages
        super
      else
        logger.warn do
          "Message is not routed! #{{ message: message, return_info: return_info, properties: properties }}"
        end
      end
    end
  end
end
