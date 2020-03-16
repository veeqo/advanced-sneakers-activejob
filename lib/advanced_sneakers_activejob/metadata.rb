# frozen_string_literal: true

module AdvancedSneakersActiveJob
  # AMQP message contains metadata which might be helpful for consumer (e.g. job.delivery_info.routing_key)
  module Metadata
    extend ActiveSupport::Concern

    included do
      # AMQP message metadata
      attr_accessor :delivery_info, :headers
    end

    module ClassMethods
      def deserialize(job_data)
        super(job_data).tap do |job|
          job.delivery_info = job_data['delivery_info']
          job.headers = job_data['headers']
        end
      end
    end
  end
end
