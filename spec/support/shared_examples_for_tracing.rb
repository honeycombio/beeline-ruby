require 'set'

RSpec.shared_examples_for 'tracing' do
  it 'includes the same trace id in all the events' do
    expect(events.first.data).to include('trace.trace_id')
    trace_id = events.first.data['trace.trace_id']

    expect(events.map(&:data)).to all(include 'trace.trace_id' => trace_id)
  end

  it 'includes a unique span id in each event' do
    span_ids = Set.new
    events.each do |event|
      expect(event.data).to include('trace.span_id')
      span_id = event.data['trace.span_id']
      span_ids << span_id
    end

    expect(span_ids.size).to eq(events.size), 'each span id should be unique'
  end

  it 'emits events that make up a valid trace' do
    span_ids = Set.new
    spans_by_parent = Hash.new {|h, k| h[k] = [] }

    events.each do |event|
      span_id = event.data['trace.span_id']
      span_ids << span_id

      parent_id = event.data['trace.parent_id']
      spans_by_parent[parent_id] << event
    end

    root_spans = spans_by_parent.delete(nil) # spans with a nil parent
    expect(root_spans.size).to eq(1)

    spans_by_parent.each do |parent_id, spans|
      expect(span_ids).to include(parent_id),
        "spans with nonexistent parent: #{spans.map {|event| event.data['type'] }.join(', ')}"
    end
  end
end
