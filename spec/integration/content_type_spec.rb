# frozen_string_literal: true

describe 'Message content type in RabbitMQ', :rabbitmq do
  subject { message.fetch('properties').fetch('content_type') }
  let(:message) { rabbitmq_messages('default').first }

  before do
    in_app_process(adapter: :advanced_sneakers) { ApplicationJob.perform_later('whatever') }
  end

  it "has 'application/vnd.activejob+json' content type" do
    expect(subject).to eq('application/vnd.activejob+json')
  end
end
