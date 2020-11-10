require 'spec_helper'

if defined?(Honeycomb::Railtie)
  RSpec.describe Honeycomb::Railtie do
    describe '.insert_honeycomb_middleware' do
      context 'when no Honeycomb client exists' do
        before do
          allow(Honeycomb).to receive(:client).and_return(hc_client)
        end

        it 'does nothing' do

        end
      end

      context 'when a Honeycomb client exists' do
        let(:hc_client) { double('Honeycomb::Client') }

        before do
          allow(Honeycomb).to receive(:client).and_return(hc_client)
        end
      end
    end
  end
end
