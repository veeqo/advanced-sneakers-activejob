# frozen_string_literal: true

describe 'rake sneakers:run', :rabbitmq do
  before { cleanup_logs }

  def publish_messages
    in_app_process(adapter: :advanced_sneakers) do
      SampleConsumer.enqueue('sneakers worker data')
      SampleMailer.greetings(name: 'Mailer').deliver_later
      CustomQueueJob.perform_later('activejob worker data')
    end
  end

  context 'when advanced_sneakers activejob_workers_strategy is set with :include' do
    it 'processes jobs for both Sneakers and ActiveJob workers' do
      in_app_process(adapter: :advanced_sneakers) do
        AdvancedSneakersActiveJob.configure { |c| c.activejob_workers_strategy = :include }

        require 'rake'
        require 'sneakers/tasks'
        Rake::Task['sneakers:run'].invoke
      end

      publish_messages

      expect_logs name: 'rails',
                  to_include: [
                    "Performing 'sneakers worker data'",
                    "Performing 'activejob worker data'",
                    /Performing ActionMailer::(Mail)?DeliveryJob/
                  ]
    end
  end

  context 'when advanced_sneakers activejob_workers_strategy is set with :exclude' do
    it 'processes jobs for Sneakers workers only' do
      in_app_process(adapter: :advanced_sneakers) do
        AdvancedSneakersActiveJob.configure { |c| c.activejob_workers_strategy = :exclude }

        require 'rake'
        require 'sneakers/tasks'
        Rake::Task['sneakers:run'].invoke
      end

      publish_messages

      expect_logs name: 'rails',
                  to_include: "Performing 'sneakers worker data'",
                  to_exclude: [
                    "Performing 'activejob worker data'",
                    /Performing ActionMailer::(Mail)?DeliveryJob/
                  ]
    end
  end

  context 'when advanced_sneakers activejob_workers_strategy is set with :only' do
    it 'processes jobs for ActiveJob workers only' do
      in_app_process(adapter: :advanced_sneakers) do
        AdvancedSneakersActiveJob.configure { |c| c.activejob_workers_strategy = :only }

        require 'rake'
        require 'sneakers/tasks'
        Rake::Task['sneakers:run'].invoke
      end

      publish_messages

      expect_logs name: 'rails',
                  to_include: [
                    "Performing 'activejob worker data'",
                    /Performing ActionMailer::(Mail)?DeliveryJob/
                  ],
                  to_exclude: "Performing 'sneakers worker data'"
    end
  end

  context 'when WORKERS variable is set' do
    it 'processes jobs for given workers only' do
      in_app_process(adapter: :advanced_sneakers) do
        ENV['WORKERS'] = 'AdvancedSneakersActiveJob::MailersConsumer'

        require 'rake'
        require 'sneakers/tasks'
        Rake::Task['sneakers:run'].invoke
      end

      publish_messages

      expect_logs name: 'rails',
                  to_include: [
                    /Performing ActionMailer::(Mail)?DeliveryJob/
                  ],
                  to_exclude: [
                    "Performing 'activejob worker data'",
                    "Performing 'sneakers worker data'"
                  ]
    end
  end
end
