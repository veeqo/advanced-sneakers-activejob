# frozen_string_literal: true

require 'sneakers/tasks'

task :environment

namespace :sneakers do
  desc 'Start work for ActiveJob only (set $QUEUES=foo,bar.baz for processing of "foo" and "bar.baz" queues)'
  task :active_job do
    Rake::Task['environment'].invoke

    populate_workers_by_queues if ENV['WORKERS'].blank? && ENV['QUEUES'].present?

    # Enforsing ActiveJob-only workers
    AdvancedSneakersActiveJob.configure { |c| c.activejob_workers_strategy = :only }

    Sneakers.configure(AdvancedSneakersActiveJob.config.sneakers)

    Sneakers.logger.level = AdvancedSneakersActiveJob.config.log_level

    Rake::Task['sneakers:run'].invoke
  end

  def populate_workers_by_queues
    require 'advanced_sneakers_activejob/support/locate_workers_by_queues'
    ::Rails.application.eager_load!

    queues = ENV['QUEUES'].split(',')
    workers = AdvancedSneakersActiveJob::Support::LocateWorkersByQueues.new(queues).call

    ENV['WORKERS'] = workers.map(&:name).join(',')
  end
end
