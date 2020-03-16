# frozen_string_literal: true

describe 'AMQP metadata', :rabbitmq do
  subject do
    in_app_process(adapter: :advanced_sneakers) do
      CustomQueueJob.before_perform do |job|
        logger.info("My routing key is '#{job.delivery_info.routing_key}'")
        logger.info("My message content type is '#{job.headers[:content_type]}'")
      end

      require 'rake'
      require 'sneakers/tasks'
      Rake::Task['sneakers:run'].invoke
    end

    in_app_process(adapter: :advanced_sneakers) { CustomQueueJob.perform_later('advanced sneakers') }
  end

  before { cleanup_logs }

  it 'is exposed to an ActiveJob worker' do
    subject

    expect_logs name: 'rails',
                to_include: [
                  "My routing key is 'custom'",
                  "My message content type is 'application/json'"
                ]
  end
end
