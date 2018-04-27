module Honeycomb
  ENV_CONFIG = begin
    writekey = ENV['HONEYCOMB_WRITEKEY']
    dataset = ENV['HONEYCOMB_DATASET'] || ENV['PWD'].split('/').last

    if writekey
      {writekey: writekey, dataset: dataset}.freeze
    end
  end
end
