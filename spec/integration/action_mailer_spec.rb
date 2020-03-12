# frozen_string_literal: true

describe 'ActiveJob support of ActionMailer' do
  context 'when Rails application has ActionMailer enabled' do
    let(:workers_class_names) do
      in_child_process('with_advanced_sneakers_adapter') do
        Sneakers::Worker::Classes.activejob_workers.map(&:name)
      end.first
    end

    it 'tracks ActionMailer job consumer' do
      expect(workers_class_names).to include('ActionMailer::DeliveryJob::Consumer')
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
