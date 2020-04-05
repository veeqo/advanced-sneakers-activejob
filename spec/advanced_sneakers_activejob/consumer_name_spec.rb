# frozen_string_literal: true

describe AdvancedSneakersActiveJob, '.consumer_name' do
  subject { described_class.consumer_name(queue_name: queue_name) }

  {
    'default' => 'DefaultConsumer',
    'foo:bar' => 'FooBarConsumer',
    '_foo ' => 'FooConsumer',
    'foo.bar.baz' => 'FooBarBazConsumer',
    'qüeüe' => 'QueueConsumer',
    '99' => 'Queue99Consumer'
  }.each do |name, expected_consumer_name|
    context "when queue name is '#{name}'" do
      let(:queue_name) { name }

      it { is_expected.to eq expected_consumer_name }
    end
  end
end
