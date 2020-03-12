# frozen_string_literal: true

describe Sneakers::Worker::Classes do
  subject { described_class }

  it 'is replaced by instance of AdvancedSneakersActiveJob::WorkersRegistry' do
    expect(subject).to be_a(AdvancedSneakersActiveJob::WorkersRegistry)
  end
end
