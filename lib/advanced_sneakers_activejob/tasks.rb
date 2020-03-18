# frozen_string_literal: true

require 'sneakers/tasks'

task :environment

namespace :sneakers do
  desc 'Start work for ActiveJob only (set $WORKERS=ActiveJobKlass1::Consumer,ActiveJobKlass2::Consumer)'
  task :active_job do
    Rake::Task['environment'].invoke

    # Enforsing ActiveJob-only workers
    AdvancedSneakersActiveJob.configure { |c| c.activejob_workers_strategy = :only }

    Sneakers.configure(AdvancedSneakersActiveJob.config.sneakers)

    Sneakers.logger.level = Logger::INFO # debug logs are too noizy because of bunny

    Rake::Task['sneakers:run'].invoke
  end
end
