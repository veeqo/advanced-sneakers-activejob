# frozen_string_literal: true

describe 'Safe publishing', :rabbitmq do
  context 'when safe_publish is on' do
    subject do
      in_app_process(adapter: :advanced_sneakers) do
        AdvancedSneakersActiveJob.configure { |c| c.safe_publish = true }
        CustomQueueJob.perform_later('this message wond be lost')
      end
    end

    it 'creates queue before publishing' do
      expect do
        subject
      end.to change { rabbitmq_queues(columns: [:name]) }.from([]).to([{ 'name' => 'custom' }])
    end

    it 'message is not lost' do
      subject
      message = rabbitmq_messages('custom').first

      expect(message['payload']).to include('this message wond be lost')
    end
  end

  context 'when safe_publish is off' do
    subject do
      in_app_process(adapter: :advanced_sneakers) do
        AdvancedSneakersActiveJob.configure { |c| c.safe_publish = false }
        CustomQueueJob.perform_later('I have configured RMQ routing in advance')
      end
    end

    it 'does not create queue before publishing' do
      expect do
        subject
      end.not_to change { rabbitmq_queues(columns: [:name]) }.from([])
    end
  end
end
