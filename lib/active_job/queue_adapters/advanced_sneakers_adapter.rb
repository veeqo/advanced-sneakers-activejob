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
      @queues = {}

      class << self
        def enqueue(job) #:nodoc:
          @monitor.synchronize do
            queue_name = job.queue_name.respond_to?(:call) ? job.queue_name.call : job.queue_name
            routing_key = job.respond_to?(:routing_key) ? job.routing_key : queue_name

            ensure_queue_exists(queue_name, routing_key) if safe_publish

            publisher.publish ActiveSupport::JSON.encode(job.serialize),
                              routing_key: routing_key,
                              content_type: 'application/json'
          end
        end

        def enqueue_at(*) #:nodoc:
          raise NotImplementedError, 'Use a queueing backend to enqueue jobs in the future. Read more at http://guides.rubyonrails.org/active_job_basics.html'
        end

        private

        delegate :bind_by_queue_name, :sneakers, :safe_publish, to: :'AdvancedSneakersActiveJob.config'

        def ensure_queue_exists(queue_name, routing_key)
          @queues[queue_name] ||= begin
            queue = publisher.channel.queue(queue_name, sneakers.fetch(:queue_options))
            queue.bind(publisher.exchange, routing_key: routing_key)
            queue.bind(publisher.exchange, routing_key: queue_name) if queue_name != routing_key && bind_by_queue_name
            true
          end
        end

        def publisher
          @publisher ||= begin
            Sneakers.configure(sneakers) unless Sneakers.configured?

            Sneakers::Publisher.new(sneakers).tap(&:ensure_connection!)
          end
        end
      end

      delegate :enqueue, :enqueue_at, to: :'ActiveJob::QueueAdapters::AdvancedSneakersAdapter' # compatibility with Rails 5+

      class JobWrapper #:nodoc:
        include Sneakers::Worker
        from_queue 'default' # no queue params here to preserve compatibility with default :sneakers adapter

        def work_with_params(msg, _delivery_info, _metadata)
          # TODO: bypass metadata to job (maybe check arity and append to args?)
          Base.execute ActiveSupport::JSON.decode(msg)
          ack!
        end
      end
    end
  end
end
