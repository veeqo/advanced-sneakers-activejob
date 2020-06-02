# frozen_string_literal: true

module AdvancedSneakersActiveJob
  # Sneakers uses Sneakers::Worker::Classes array to track all workers.
  # WorkersRegistry mocks original array to track ActiveJob workers separately.
  class WorkersRegistry
    attr_reader :sneakers_workers

    delegate :activejob_workers_strategy, to: :'AdvancedSneakersActiveJob.config'

    delegate :empty?, to: :call

    def initialize
      @sneakers_workers = []
      @activejob_workers = []
    end

    def <<(worker)
      if worker <= ActiveJob::QueueAdapters::AdvancedSneakersAdapter::JobWrapper
        @activejob_workers << worker
      else
        sneakers_workers << worker
      end
    end

    # Sneakers workergroup supports callable objects.
    # https://github.com/jondot/sneakers/pull/210/files
    # https://github.com/jondot/sneakers/blob/7a972d22a58de8a261a738d9a1e5fb51f9608ede/lib/sneakers/workergroup.rb#L28
    def call
      case activejob_workers_strategy
      when :only    then activejob_workers
      when :exclude then sneakers_workers
      when :include then sneakers_workers + activejob_workers
      else
        raise "Unknown activejob_workers_strategy '#{activejob_workers_strategy}'"
      end
    end

    def to_hash
      {
        sneakers_workers: sneakers_workers,
        activejob_workers: activejob_workers
      }
    end

    alias to_h to_hash

    # For cleaner output on inspecting Sneakers::Worker::Classes in console.
    alias inspect to_hash

    def activejob_workers
      define_active_job_consumers

      @activejob_workers
    end

    def method_missing(method_name, *args, &block)
      if call.respond_to?(method_name)
        call.send(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      call.respond_to?(method_name) || super
    end

    private

    def define_active_job_consumers
      active_job_classes_with_matching_adapter.each do |worker|
        AdvancedSneakersActiveJob.define_consumer(queue_name: worker.new.queue_name)
      end
    end

    def active_job_classes_with_matching_adapter
      ([ActiveJob::Base] + ActiveJob::Base.descendants).select do |klass|
        klass.queue_adapter == ::ActiveJob::QueueAdapters::AdvancedSneakersAdapter ||
          klass.queue_adapter.is_a?(::ActiveJob::QueueAdapters::AdvancedSneakersAdapter)
      end
    end
  end
end
