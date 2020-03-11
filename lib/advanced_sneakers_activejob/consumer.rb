# frozen_string_literal: true

module AdvancedSneakersActiveJob
  # ActiveJob Sneakers adapter uses single consumer with "default" queue and ignores `queue_as` of ActiveJob
  # https://github.com/rails/rails/blob/2a0823ecbaeb3a6fbedc5cc31879d68fdf27d0cb/activejob/lib/active_job/queue_adapters/sneakers_adapter.rb#L38
  # Advanced Sneakers adapter defines consumer per ActiveJob class (e.g. SampleJob::Consumer) with queue_name from `queue_as`
  module Consumer
    def queue_as(*args)
      super(*args)
      define_consumer
    end

    private

    def define_consumer
      klass = Class.new(ActiveJob::QueueAdapters::AdvancedSneakersAdapter::JobWrapper)
      klass.include Sneakers::Worker
      const_set('Consumer', klass)
      klass.from_queue(queue_name, AdvancedSneakersActiveJob.config.sneakers)
    end
  end
end
