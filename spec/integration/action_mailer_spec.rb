# frozen_string_literal: true

describe 'ActiveJob support of ActionMailer' do
  context 'when Rails application has ActionMailer enabled' do
    context 'when :sneakers adapter is used' do
      it 'loses emails' do
        cleanup_logs
        start_sneakers_consumers('with_sneakers_adapter')

        in_child_process('with_sneakers_adapter') do
          SampleMailer.greetings(name: 'Sneakers').deliver_later
          sleep(0.05)
        end

        log = logs('rails')
        expect(log).to include('Enqueued ActionMailer::DeliveryJob to Sneakers(mailers) with arguments: "SampleMailer", "greetings", "deliver_now", {:name=>"Sneakers"}')
        expect(log).not_to include('Hello, Sneakers')
        expect(log).not_to include('Performed ActionMailer::DeliveryJob')
      end
    end

    context 'when :advanced_sneakers adapter is used' do
      it 'processes emails' do
        cleanup_logs
        start_sneakers_consumers('with_advanced_sneakers_adapter')

        in_child_process('with_sneakers_adapter') do
          SampleMailer.greetings(name: 'Advanced sneakers').deliver_later
          sleep(0.05)
        end

        log = logs('rails')
        expect(log).to include('Enqueued ActionMailer::DeliveryJob to Sneakers(mailers) with arguments: "SampleMailer", "greetings", "deliver_now", {:name=>"Advanced sneakers"}')
        expect(log).to include('Hello, Advanced sneakers')
        expect(log).to include('Performed ActionMailer::DeliveryJob')
      end
    end
  end

  context 'when Rails application has ActionMailer disabled' do
    let(:workers_class_names) do
      in_child_process('with_advanced_sneakers_adapter', env: { 'SKIP_MAILER' => '1' }) do
        Sneakers::Worker::Classes.activejob_workers.map(&:name)
      end.first
    end

    it 'does not have ActionMailer job consumer' do
      expect(workers_class_names).not_to include('ActionMailer::DeliveryJob::Consumer')
    end
  end
end
