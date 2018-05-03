module Honeycomb
  ENV_CONFIG = begin
    writekey = ENV['HONEYCOMB_WRITEKEY']
    dataset = ENV['HONEYCOMB_DATASET'] || ENV['PWD'].split('/').last

    withouts = ENV['HONEYCOMB_WITHOUT'] || ''
    without = withouts.split(',').map(&:to_sym)

    if writekey
      {writekey: writekey, dataset: dataset, without: without}.freeze
    end
  end

  DEBUG = if ENV.key?('HONEYCOMB_DEBUG')
    ENV['HONEYCOMB_DEBUG'].upcase.to_sym
  end
end
