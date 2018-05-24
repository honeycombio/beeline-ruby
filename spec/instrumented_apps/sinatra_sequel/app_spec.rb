require 'socket'

require 'instrumented_apps/sinatra_sequel/app'
require 'support/fakehoney'
require 'support/shared_examples_for_tracing'

RSpec.describe SinatraSequelApp do
  after { $fakehoney.reset }

  let(:app) { SinatraSequelApp }

  let(:hostname) { Socket.gethostname }
  let(:beeline_meta_fields) { {
    'meta.local_hostname' => hostname,
    'meta.beeline_version' => Honeycomb::Beeline::VERSION,
    'service_name' => 'sinatra_sequel',
  } }

  context 'web request making several database queries' do
    before do
      put '/animals', {name: 'Bucky', species: 'Hare'}.to_json
      expect(last_response.status).to be <= 299
    end

    let(:events) { $fakehoney.events }

    it 'emits two db events followed by an http_server event' do
      # Sometimes we pick up Sequel's metadata queries here - it seems to be
      # nondeterministic, so maybe there is a race with some Sequel internal
      # state?
      # To avoid depending on the outcome of this race, we just assert that we
      # saw at least two 'db' events and that the 'http_server' event was last.
      types = events.map {|event| event.data['type'] }
      expect(types.pop).to eq 'http_server'

      # pop mutates the 'types' list, so now just the db events should remain
      expect(types).to all(eq 'db')
      expect(types.size).to be >= 2
    end

    it 'includes beeline meta fields in all the events' do
      expect(events.map(&:data)).to all(include beeline_meta_fields)
      expect(events.map(&:data)).to all(include 'meta.package')
    end

    include_examples 'tracing'
  end
end
