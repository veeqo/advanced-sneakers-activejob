# frozen_string_literal: true

module AdvancedSneakersActiveJob
  module ActiveJobPatch
    extend ActiveSupport::Concern

    included do
      # AMQP message contains metadata which might be helpful for consumer (e.g. job.delivery_info.routing_key)
      attr_accessor :delivery_info, :headers

      class_attribute :publish_options, instance_accessor: false
    end

    module ClassMethods
      def deserialize(job_data)
        super(job_data).tap do |job|
          job.delivery_info = job_data['delivery_info']
          job.headers = job_data['headers']
        end
      end

      def queue_as(*args)
        super(*args)
        define_consumer
      end

      def message_options(options)
        raise ArgumentError, 'message_options accepts Hash argument only' unless options.is_a?(Hash)

        self.publish_options = options.symbolize_keys
      end

      private

      def define_consumer
        AdvancedSneakersActiveJob.define_consumer(queue_name: queue_name_without_prefix)
      end

      def queue_name_without_prefix
        name = queue_name.respond_to?(:call) ? queue_name.call : queue_name

        return name if queue_name_prefix.blank?

        name.to_s.sub([queue_name_prefix, queue_name_delimiter].join, '')
      end
    end
  end
end
