# frozen_string_literal: true

describe AdvancedSneakersActiveJob::Configuration, '.sneakers' do
  subject { AdvancedSneakersActiveJob.config.sneakers }

  context 'when no config for sneakers is set', with_config: { sneakers: nil } do
    it 'proxies Sneakers::CONFIG' do
      expect(subject.values_at(:exchange, :heartbeat)).to eq(['activejob', 30])
    end
  end

  context 'when custom config for sneakers is set' do
    context 'when exchange is set', with_config: { sneakers: { exchange: 'foobar' } } do
      it 'merges custom config with Sneakers::CONFIG' do
        expect(subject.values_at(:exchange, :heartbeat)).to eq(['foobar', 30])
      end
    end

    context 'when amqp is set', with_config: { sneakers: { amqp: 'amqp://server/custom_host' } } do
      it 'also overwrites vhost' do
        expect(subject.values_at(:amqp, :vhost)).to eq(['amqp://server/custom_host', 'custom_host'])
      end
    end

    context 'when amqp and vhost are set', with_config: { sneakers: { amqp: 'amqp://server/custom_host', vhost: 'foobar' } } do
      it 'also overwrites vhost' do
        expect(subject.values_at(:amqp, :vhost)).to eq(['amqp://server/custom_host', 'foobar'])
      end
    end
  end
end
