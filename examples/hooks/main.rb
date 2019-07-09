require "honeycomb-beeline"

class CustomSampler
  extend Honeycomb::DeterministicSampler

  def self.sample(fields)
    case fields["app.response_code"]
    when 0
      [false, 0]
    when 200
      rate = 100
      [should_sample(rate, fields["trace.trace_id"]), rate]
    else
      [true, 1]
    end
  end
end

Honeycomb.configure do |config|
  config.write_key = "write_key"
  config.dataset = "dataset"
  config.service_name = "service_name"
  config.client = Libhoney::LogClient.new
  config.presend_hook do |fields|
    if fields.has_key? "app.credit_card_number"
      fields["app.credit_card_number"] = "[REDACTED]"
    end
  end
  config.sample_hook do |fields|
    CustomSampler.sample(fields)
  end
end

Honeycomb.start_span(name: "hook_span") do
  Honeycomb.add_field("response_code", 200)
  Honeycomb.add_field("credit_card_number", "4242424242424242")
end
