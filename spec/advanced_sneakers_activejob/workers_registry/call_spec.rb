# frozen_string_literal: true

describe AdvancedSneakersActiveJob::WorkersRegistry, '#call' do
  subject { registry.call }

  let(:registry) { described_class.new }

  let(:activejob_class) { Class.new(ActiveJob::QueueAdapters::AdvancedSneakersAdapter::JobWrapper) }
  let(:other_class) { Class.new }

  before do
    allow(registry).to receive(:activejob_workers).and_return([activejob_class])
    registry << other_class
  end

  context 'when strategy is :include', with_config: { activejob_workers_strategy: :include } do
    it 'returns all registered workers' do
      expect(subject).to match_array([activejob_class, other_class])
    end
  end

  context 'when strategy is :exclude', with_config: { activejob_workers_strategy: :exclude } do
    it 'does not return ActiveJob workers' do
      expect(subject).to match_array([other_class])
    end
  end

  context 'when strategy is :only', with_config: { activejob_workers_strategy: :only } do
    it 'returns ActiveJob workers only' do
      expect(subject).to match_array([activejob_class])
    end
  end

  context 'when unknown strategy is set', with_config: { activejob_workers_strategy: :foobar } do
    it 'raises error' do
      expect { subject }.to raise_error(RuntimeError, "Unknown activejob_workers_strategy 'foobar'")
    end
  end
end
