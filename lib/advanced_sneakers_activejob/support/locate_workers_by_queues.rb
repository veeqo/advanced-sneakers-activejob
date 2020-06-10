# frozen_string_literal: true

module AdvancedSneakersActiveJob
  module Support
    class LocateWorkersByQueues
      def initialize(queues)
        @queues = queues.uniq.reject(&:blank?)
        @queues_without_workers = []
        @workers = []
      end

      def call
        detect_workers_for_queues!
        ensure_all_workers_found!

        @workers.uniq
      end

      private

      def ensure_all_workers_found!
        return if @queues_without_workers.empty?

        raise("Missing workers for queues: #{@queues_without_workers.join(', ')}")
      end

      def all_workers
        @all_workers ||= Sneakers::Worker::Classes.activejob_workers
      end

      def detect_workers_for_queues!
        @queues.each do |queue|
          matching_workers = all_workers.select { |klass| klass.queue_name.match?(queue_regex(queue)) }

          if matching_workers.any?
            @workers += matching_workers
          else
            @queues_without_workers << queue
          end
        end
      end

      # https://www.rabbitmq.com/tutorials/tutorial-five-python.html
      def queue_regex(queue)
        regex = Regexp.escape(queue)
                      .gsub(/\A\\\*|(\.)\\\*/, '\1[^\.]+') # "*" (star) substitutes for exactly one word
                      .sub('\.\#', '(\.[^\.]+)*') # "#" (hash) substitutes for zero or more words

        Regexp.new(['\A', regex, '\z'].join)
      end
    end
  end
end
