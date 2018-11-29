require 'honeycomb/span'

RSpec.describe 'trace context' do
  def encode(*args)
    Honeycomb.encode_trace_context(*args)
  end

  def decode(*args)
    Honeycomb.decode_trace_context(*args)
  end

  describe 'roundtrip' do
    specify 'encoding then decoding preserves a context' do
      trace_id = 'abcdef123456'
      parent_span_id = '0102030405'
      context = {
        'custom_context' => {
          'user_id' => 1,
          'error_msg' => 'failed to sign on',
          'to_retry' => true,
        },
      }

      expect(decode(encode(trace_id, parent_span_id, context))).to eq(
        trace_id: trace_id,
        parent_span_id: parent_span_id,
        context: context,
      )
    end

    specify 'decoding then encoding preserves an encoded context' do
      encoded_context = "1;trace_id=abcdef123456,parent_id=0102030405,context=#{Base64.encode64('{"foo":"bar","baz":[1,2,3]}').strip}"

      context = decode(encoded_context)
      reencoded = encode(context[:trace_id], context[:parent_span_id], context[:context])
      expect(reencoded).to eq(encoded_context)
    end
  end

  describe 'encoding' do
    it 'encodes as a string' do
      expect(encode('abcd', 'efgh', foo: 'bar')).to be_a String
    end

    it 'prefixes with the version' do
      expect(encode('abcd', 'efgh', foo: 'bar')).to start_with('1')
    end

    it 'does not add newlines for large contexts' do
      expect(encode('abcd', 'efgh', foo: 'bar'*32)).to_not include("\n")
    end
  end

  describe 'decoding' do
    [
      {
        description: "unsupported version",
        encoded_context: "9999999;.....",
        expected: nil,
      },
      {
        description: "v1 trace_id + parent_id, missing context",
        encoded_context: "1;trace_id=abcdef,parent_id=12345",
        expected: {
          trace_id: "abcdef",
          parent_span_id: "12345",
        },
      },
      {
        description: "v1, missing trace_id",
        encoded_context: "1;parent_id=12345",
        expected: nil,
      },
      {
        description: "v1, missing parent_id",
        encoded_context: "1;trace_id=12345",
        expected: nil,
      },
      {
        description: "v1, garbled context",
        encoded_context: "1;trace_id=abcdef,parent_id=12345,context=123~!@@&^@",
        expected: nil,
      },
      {
        description: "v1, unknown key (otherwise valid)",
        encoded_context: "1;trace_id=abcdef,parent_id=12345,something=unsupported",
        expected: {
          trace_id: "abcdef",
          parent_span_id: "12345",
        },
      },
    ].each do |description:, encoded_context:, expected:|
      it "#{expected ? 'decodes' : 'refuses to decode'} #{description}" do
        expect(decode(encoded_context)).to eq(expected)
      end
    end
  end
end
