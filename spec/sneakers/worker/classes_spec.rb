# frozen_string_literal: true

describe Sneakers::Worker::Classes do
  subject { described_class }

  it 'is replaced by instance of AdvancedSneakersActiveJob::WorkersRegistry' do
    expect(subject).to be_a(AdvancedSneakersActiveJob::WorkersRegistry)
  end

  describe 'ActiveJob support of ActionMailer' do
    context 'when Rails application has ActionMailer enabled' do
      let(:workers_class_names) do
        in_child_process do
          require 'rails'
          require 'active_job/railtie'
          require 'action_mailer/railtie'

          require 'advanced_sneakers_activejob/railtie'

          class App < Rails::Application
            config.active_job.queue_adapter = :advanced_sneakers
            config.eager_load = true
            config.logger = Logger.new(nil)
          end

          App.initialize!

          Sneakers::Worker::Classes.activejob_workers.map(&:name)
        end
      end

      it 'tracks ActionMailer job consumer' do
        expect(workers_class_names).to include('ActionMailer::DeliveryJob::Consumer')
      end
    end

    context 'when Rails application has ActionMailer disabled' do
      let(:workers_class_names) do
        in_child_process do
          require 'rails'
          require 'active_job/railtie'

          require 'advanced_sneakers_activejob/railtie'

          class App < Rails::Application
            config.active_job.queue_adapter = :advanced_sneakers
            config.eager_load = true
            config.logger = Logger.new(nil)
          end

          App.initialize!

          Sneakers::Worker::Classes.activejob_workers.map(&:name)
        end
      end

      it 'does not have ActionMailer job consumer' do
        expect(workers_class_names).not_to include('ActionMailer::DeliveryJob::Consumer')
      end
    end
  end
end
