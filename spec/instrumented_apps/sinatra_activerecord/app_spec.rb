require 'socket'

require 'instrumented_apps/sinatra_activerecord/app'
require 'support/fakehoney'
require 'support/shared_examples_for_tracing'

RSpec.describe SinatraActiveRecordApp do
  after { $fakehoney.reset }

  let(:app) { SinatraActiveRecordApp }

  let(:hostname) { Socket.gethostname }
  let(:beeline_meta_fields) { {
    'meta.local_hostname' => hostname,
    'meta.beeline_version' => Honeycomb::Beeline::VERSION,
    'service_name' => 'sinatra_activerecord',
  } }

  context 'simple web request' do
    before do
      get '/'
      expect(last_response).to be_ok
    end

    it 'should emit only one event' do
      expect($fakehoney.events.size).to eq 1
    end

    let(:event_data) do
      event = $fakehoney.events.last
      expect(event).to_not be_nil
      event.data
    end

    subject do
      event_data
    end

    it 'emits an http_server event' do
      expect(event_data).to include(
        'type' => 'http_server',
        'request.path' => '/',
      )
    end

    it 'includes beeline meta fields' do
      expect(event_data).to include beeline_meta_fields
      expect(event_data).to include 'meta.package'
    end
  end

  context 'web request making several database queries' do
    before do
      put '/animals', {name: 'Bucky', species: 'Hare'}.to_json
      expect(last_response.status).to be <= 299
    end

    let(:events) { $fakehoney.events }

    it 'emits two db events followed by an http_server event' do
      expect(events.map {|event| event.data['type'] }).to eq %w(db db http_server)
    end

    it 'includes beeline meta fields in all the events' do
      expect(events.map(&:data)).to all(include beeline_meta_fields)
      expect(events.map(&:data)).to all(include 'meta.package')
    end

    include_examples 'tracing'
  end

  context 'web request making an outbound HTTP request' do
    before do
      post '/login'
      expect(last_response).to be_ok
    end

    let(:events) { $fakehoney.events }

    it 'emits an http_client event followed by an http_server event' do
      expect(events.map {|event| event.data['type'] }).to eq %w(http_client http_server)
    end

    it 'includes beeline meta fields in all the events' do
      expect(events.map(&:data)).to all(include beeline_meta_fields)
      expect(events.map(&:data)).to all(include 'meta.package')
    end

    include_examples 'tracing'
  end

  context 'web request with user instrumentation' do
    before do
      get '/microanimals'
      expect(last_response).to be_ok
    end

    let(:events) { $fakehoney.events }

    it 'emits user instrumentation events followed by an http_server event' do
      pending 'span should include type'

      expect(events.map {|event| event.data['type'] }).to eq %w(animals_client animals_client render http_server)
    end

    it 'includes beeline meta fields in all the events' do
      pending 'span should include something for meta.package'

      expect(events.map(&:data)).to all(include beeline_meta_fields)
      expect(events.map(&:data)).to all(include 'meta.package')
    end

    include_examples 'tracing'
  end
end
