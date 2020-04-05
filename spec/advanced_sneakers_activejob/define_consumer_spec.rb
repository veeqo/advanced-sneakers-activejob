# frozen_string_literal: true

describe AdvancedSneakersActiveJob, '.define_consumer' do
  context 'when called multiple times with different queue names' do
    let(:consumer1) { described_class.define_consumer(queue_name: 'unique_queue_1') }
    let(:consumer2) { described_class.define_consumer(queue_name: 'unique_queue_2') }

    it 'defines consumers per queue' do
      expect(consumer1).not_to be(consumer2)
    end
  end

  context 'when called multiple times with same queue names' do
    let(:consumer1) { described_class.define_consumer(queue_name: 'non_unique_queue') }
    let(:consumer2) { described_class.define_consumer(queue_name: 'non_unique_queue') }

    it 'does not define new consumer' do
      expect(consumer1).to be(consumer2)
    end
  end
end
