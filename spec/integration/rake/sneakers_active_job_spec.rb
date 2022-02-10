# frozen_string_literal: true

describe 'rake sneakers:active_job', :rabbitmq do
  before { cleanup_logs }

  def publish_messages
    in_app_process(adapter: :advanced_sneakers) do
      SampleConsumer.enqueue('sneakers worker data')
      SampleMailer.greetings(name: 'Mailer').deliver_later
      CustomQueueJob.perform_later('activejob worker data')
    end
  end

  context 'when QUEUES variable is unset' do
    it 'processes jobs for all ActiveJob workers' do
      in_app_process(adapter: :advanced_sneakers) do
        require 'rake'
        require 'advanced_sneakers_activejob/tasks'
        Rake::Task['sneakers:active_job'].invoke
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

  context 'when QUEUES variable is set' do
    it 'processes jobs for matching ActiveJob workers only' do
      in_app_process(adapter: :advanced_sneakers) do
        ENV['QUEUES'] = 'mailers'

        require 'rake'
        require 'advanced_sneakers_activejob/tasks'
        Rake::Task['sneakers:active_job'].invoke
      end

      publish_messages

      expect_logs name: 'rails',
                  to_include: /Performing ActionMailer::(Mail)?DeliveryJob/,
                  to_exclude: [
                    "Performing 'activejob worker data'",
                    "Performing 'sneakers worker data'"
                  ]
    end
  end
end
