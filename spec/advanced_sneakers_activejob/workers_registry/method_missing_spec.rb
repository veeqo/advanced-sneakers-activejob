# frozen_string_literal: true

describe AdvancedSneakersActiveJob::WorkersRegistry do
  let(:registry) { described_class.new }

  let(:activejob_class) { Class.new(ActiveJob::QueueAdapters::AdvancedSneakersAdapter::JobWrapper) }
  let(:other_class) { Class.new }

  before do
    allow(registry).to receive(:activejob_workers).and_return([activejob_class])
    registry << other_class
  end

  context 'when supported method is called' do
    subject { registry.count }

    it { is_expected.to eq 2 }
  end

  context 'when unsupported method is called' do
    subject { registry.foobar }

    it 'raises NoMethodError' do
      expect { subject }.to raise_error(NoMethodError, /undefined method `foobar'/)
    end
  end
end
