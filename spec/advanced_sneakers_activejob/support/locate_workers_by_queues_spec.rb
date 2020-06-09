# frozen_string_literal: true

require 'advanced_sneakers_activejob/support/locate_workers_by_queues'

describe AdvancedSneakersActiveJob::Support::LocateWorkersByQueues do
  subject { locator.call }

  let(:locator) { described_class.new(queues) }

  let(:foo_worker) do
    Class.new do
      def self.queue_name
        'foo'
      end
    end
  end

  let(:bar_worker) do
    Class.new do
      def self.queue_name
        'bar'
      end
    end
  end

  before { allow(Sneakers::Worker::Classes).to receive(:activejob_workers).and_return([foo_worker, bar_worker]) }

  context 'when workers are found for all requested queues' do
    let(:queues) { %w[foo bar] }

    it { is_expected.to eq([foo_worker, bar_worker]) }
  end

  context 'when workers are not found for queues' do
    let(:queues) { %w[foo baz qux] }

    it 'raises error' do
      expect { subject }.to raise_error(RuntimeError, 'Missing workers for queues: baz, qux')
    end
  end
end
