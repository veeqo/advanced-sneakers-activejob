# frozen_string_literal: true

module ActiveJob
  module QueueAdapters
    # == Active Job advanced Sneakers adapter
    #
    # A high-performance RabbitMQ background processing framework for Ruby.
    # Sneakers is being used in production for both I/O and CPU intensive
    # workloads, and have achieved the goals of high-performance and
    # 0-maintenance, as designed.
    #
    # Read more about Sneakers {here}[https://github.com/jondot/sneakers].
    #
    # To use the advanced Sneakers adapter set the queue_adapter config to +:advanced_sneakers+.
    #
    #   Rails.application.config.active_job.queue_adapter = :advanced_sneakers
    class AdvancedSneakersAdapter
      @monitor = Monitor.new

      class << self
        def enqueue(job) #:nodoc:
          AdvancedSneakersActiveJob.publisher.publish(*publish_params(job))
        end

        def enqueue_at(job, timestamp) #:nodoc:
          delay = AdvancedSneakersActiveJob.config.delay_proc.call(timestamp).to_i

          if delay.positive?
            message, options = publish_params(job)
            options[:headers] = { 'delay' => delay.to_i } # do not use x- prefix because headers exchanges ignore such headers

            AdvancedSneakersActiveJob.delayed_publisher.publish(message, options)
          else
            enqueue(job)
          end
        end

        private

        def publish_params(job)
          @monitor.synchronize do
            [
              Sneakers::ContentType.serialize(job.serialize, AdvancedSneakersActiveJob::CONTENT_TYPE),
              build_publish_params(job).merge(content_type: AdvancedSneakersActiveJob::CONTENT_TYPE)
            ]
          end
        end

        def build_publish_params(job)
          params = job.class.publish_options.dup || {}

          params.each do |key, value|
            params[key] = value.call(job) if value.respond_to?(:call)
          end

          unless params.key?(:routing_key)
            params[:routing_key] = job.queue_name.respond_to?(:call) ? job.queue_name.call : job.queue_name
          end

          params
        end
      end

      delegate :enqueue, :enqueue_at, to: :'ActiveJob::QueueAdapters::AdvancedSneakersAdapter' # compatibility with Rails 5+

      class JobWrapper #:nodoc:
        def work_with_params(msg, delivery_info, headers)
          # compatibility with :sneakers adapter
          msg = ActiveSupport::JSON.decode(msg) unless headers[:content_type] == AdvancedSneakersActiveJob::CONTENT_TYPE

          msg['delivery_info'] = delivery_info
          msg['headers'] = headers
          Base.execute msg
          ack!
        end
      end
    end
  end
end
