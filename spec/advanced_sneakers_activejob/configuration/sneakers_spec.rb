# frozen_string_literal: true

describe AdvancedSneakersActiveJob::Configuration, '.sneakers' do
  subject { AdvancedSneakersActiveJob.config.sneakers }

  context 'when no config for sneakers is set', with_config: { sneakers: nil } do
    it 'proxies Sneakers::CONFIG' do
      expect(subject.values_at(:exchange, :heartbeat)).to eq(['sneakers', 30])
    end
  end

  context 'when custom config for sneakers is set', with_config: { sneakers: { exchange: 'foobar' } } do
    it 'merges custom config with Sneakers::CONFIG' do
      expect(subject.values_at(:exchange, :heartbeat)).to eq(['foobar', 30])
    end
  end

  describe 'logger' do
    subject { super()[:log] }

    it 'is taken from ActiveJob' do
      expect(subject).to eql(ActiveJob::Base.logger)
    end
  end
end
