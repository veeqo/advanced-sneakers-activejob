# frozen_string_literal: true

describe 'ActiveJob support of ActionMailer', :rabbitmq do
  context 'when Rails application has ActionMailer enabled' do
    context 'when :sneakers adapter is used' do
      it 'loses emails' do
        cleanup_logs
        start_sneakers_consumers(adapter: :sneakers)
        in_app_process(adapter: :sneakers) { SampleMailer.greetings(name: 'Sneakers').deliver_later }

        expect_logs name: 'rails',
                    to_include: 'Enqueued ActionMailer::DeliveryJob to Sneakers(mailers) with arguments: "SampleMailer", "greetings", "deliver_now", {:name=>"Sneakers"}',
                    to_exclude: [
                      'Hello, Sneakers',
                      'Performed ActionMailer::DeliveryJob'
                    ]
      end
    end

    context 'when :advanced_sneakers adapter is used' do
      it 'processes emails' do
        cleanup_logs
        start_sneakers_consumers(adapter: :advanced_sneakers)
        in_app_process(adapter: :sneakers) { SampleMailer.greetings(name: 'Advanced sneakers').deliver_later }

        expect_logs name: 'rails',
                    to_include: [
                      'Enqueued ActionMailer::DeliveryJob to Sneakers(mailers) with arguments: "SampleMailer", "greetings", "deliver_now", {:name=>"Advanced sneakers"}',
                      'Hello, Advanced sneakers',
                      'Performed ActionMailer::DeliveryJob'
                    ]
      end
    end
  end

  context 'when Rails application has ActionMailer disabled' do
    let(:workers_class_names) do
      result, _error_logs = in_app_process(adapter: :advanced_sneakers, env: { 'SKIP_MAILER' => '1' }) do
        Sneakers::Worker::Classes.activejob_workers.map(&:name)
      end

      result
    end

    it 'does not have ActionMailer job consumer' do
      expect(workers_class_names).not_to include('ActionMailer::DeliveryJob::Consumer')
    end
  end
end
