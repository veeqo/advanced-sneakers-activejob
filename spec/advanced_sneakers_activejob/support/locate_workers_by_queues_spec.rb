# frozen_string_literal: true

require 'advanced_sneakers_activejob/support/locate_workers_by_queues'

describe AdvancedSneakersActiveJob::Support::LocateWorkersByQueues do
  subject { locator.call }

  let(:locator) { described_class.new(queues) }

  let(:foo_worker) do
    Class.new do
      def self.queue_name
        'one.foo.two'
      end
    end
  end

  let(:bar_worker) do
    Class.new do
      def self.queue_name
        'one.bar.two'
      end
    end
  end

  before { allow(Sneakers::Worker::Classes).to receive(:activejob_workers).and_return([foo_worker, bar_worker]) }

  context 'when requested queues do not contain * or # chars' do
    context 'when workers are found for all requested queues' do
      let(:queues) { %w[one.foo.two one.bar.two] }

      it 'returns matching workers' do
        expect(subject).to eq([foo_worker, bar_worker])
      end
    end

    context 'when workers are not found for queues' do
      let(:queues) { %w[one.foo.two baz qux] }

      it 'raises error' do
        expect { subject }.to raise_error(RuntimeError, 'Missing workers for queues: baz, qux')
      end
    end
  end

  context 'when requested queues contain * and do not contain #' do
    context 'when requested queues match with multiple workers' do
      let(:queues) { ['one.*.two'] }

      it 'returns matching workers' do
        expect(subject).to eq([foo_worker, bar_worker])
      end
    end

    context 'when requested queues match with one worker' do
      let(:queues) { ['one.foo.*'] }

      it 'returns matching worker' do
        expect(subject).to eq([foo_worker])
      end
    end

    context 'when workers are not found for queues' do
      let(:queues) { %w[one.* *.two] }

      it 'raises error' do
        expect { subject }.to raise_error(RuntimeError, 'Missing workers for queues: one.*, *.two')
      end
    end
  end

  context 'when requested queues contain # and do not contain *' do
    context 'when requested queues match with multiple workers' do
      let(:queues) { %w[one.#] }

      it 'returns matching workers' do
        expect(subject).to eq([foo_worker, bar_worker])
      end
    end

    context 'when requested queues match with one worker' do
      let(:queues) { %w[one.foo.#] }

      it 'returns matching worker' do
        expect(subject).to eq([foo_worker])
      end
    end

    context 'when workers are not found for queues' do
      let(:queues) { %w[one#] }

      it 'raises error' do
        expect { subject }.to raise_error(RuntimeError, 'Missing workers for queues: one#')
      end
    end
  end

  context 'when requested queues contain * and #' do
    context 'when requested queues match with multiple workers' do
      let(:queues) { %w[one.*.two.#] }

      it 'returns matching workers' do
        expect(subject).to eq([foo_worker, bar_worker])
      end
    end

    context 'when requested queues match with one worker' do
      let(:queues) { %w[*.foo.#] }

      it 'returns matching worker' do
        expect(subject).to eq([foo_worker])
      end
    end

    context 'when workers are not found for queues' do
      let(:queues) { %w[on.#] }

      it 'raises error' do
        expect { subject }.to raise_error(RuntimeError, 'Missing workers for queues: on.#')
      end
    end
  end
end
