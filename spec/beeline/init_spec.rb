require 'logger'
require 'stringio'

require 'honeycomb/client'

RSpec.describe 'Honeycomb.init' do
  after { Honeycomb.reset }

  context 'with missing parameters' do
    let(:log_output) { StringIO.new }
    let(:logger) do
      logger = Logger.new(log_output)
      logger.level = Logger::WARN
      logger
    end

    it 'logs a warning if writekey is unspecified' do
      Honeycomb.init dataset: 'dummy_service', logger: logger
      expect(log_output.string).to match(/writekey/)
    end

    it 'logs a warning if dataset is unspecified' do
      Honeycomb.init writekey: 'dummy', logger: logger
      expect(log_output.string).to match(/dataset/)
    end
  end

  context 'with parameters specified explicitly' do
    it 'persists the writekey, service name and dataset' do
      Honeycomb.init writekey: 'dummy', service_name: 'test_service', dataset: 'my-test-service'

      expect(Honeycomb.service_name).to eq 'test_service'

      expect(Honeycomb.client).to_not be_nil
      expect(Honeycomb.client.writekey).to eq 'dummy'
      expect(Honeycomb.client.dataset).to eq 'my-test-service'
    end
  end

  context 'configured via environment' do
    after do
      ENV.delete 'HONEYCOMB_WRITEKEY'
      ENV.delete 'HONEYCOMB_SERVICE'
      ENV.delete 'HONEYCOMB_DATASET'
    end

    it 'picks up writekey, service name and dataset from the environment' do
      ENV['HONEYCOMB_WRITEKEY'] = 'fake'
      ENV['HONEYCOMB_SERVICE'] = 'pseudo_service'
      ENV['HONEYCOMB_DATASET'] = 'my-pseudo-service'

      Honeycomb.init

      expect(Honeycomb.client.writekey).to eq 'fake'
      expect(Honeycomb.service_name).to eq 'pseudo_service'
      expect(Honeycomb.client.dataset).to eq 'my-pseudo-service'
    end
  end

  context 'inferred parameters' do
    it 'infers service name from the dataset if not specified' do
      Honeycomb.init writekey: 'dummy', dataset: 'dummy_service'

      expect(Honeycomb.service_name).to eq 'dummy_service'
    end
  end
end
