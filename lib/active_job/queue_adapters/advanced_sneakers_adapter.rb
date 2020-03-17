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
          publisher.publish(*publish_params(job))
        end

        def enqueue_at(*) #:nodoc:
          raise NotImplementedError, 'Use a queueing backend to enqueue jobs in the future. Read more at http://guides.rubyonrails.org/active_job_basics.html'
        end

        private

        def publish_params(job)
          @monitor.synchronize do
            [
              Sneakers::ContentType.serialize(job.serialize, AdvancedSneakersActiveJob::CONTENT_TYPE),
              { routing_key: routing_key(job) }
            ]
          end
        end

        def routing_key(job)
          queue_name = job.queue_name.respond_to?(:call) ? job.queue_name.call : job.queue_name
          job.respond_to?(:routing_key) ? job.routing_key : queue_name
        end

        def publisher
          @publisher ||= AdvancedSneakersActiveJob::Publisher.new
        end
      end

      delegate :enqueue, :enqueue_at, to: :'ActiveJob::QueueAdapters::AdvancedSneakersAdapter' # compatibility with Rails 5+

      class JobWrapper #:nodoc:
        include Sneakers::Worker
        from_queue 'default' # no queue params here to preserve compatibility with default :sneakers adapter

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
