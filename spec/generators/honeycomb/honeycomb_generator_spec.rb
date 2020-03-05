# frozen_string_literal: true

if defined?(Honeycomb::Rails)
  require "generators/honeycomb/honeycomb_generator"

  RSpec.describe HoneycombGenerator do
    describe "simple execution" do
      let(:writekey) { "generator_write_key" }
      let(:default_dataset) { "rails" }
      let(:dataset) { "generator_dataset" }
      let(:init_file) { File.join(@dir, "config/initializers/honeycomb.rb") }

      around(:example) do |example|
        Dir.mktmpdir do |dir|
          Dir.chdir dir do
            @dir = dir
            example.run
          end
        end
      end

      it "creates the initializer file" do
        Rails::Generators.invoke("honeycomb", [writekey])
        expect(File.exist?(init_file)).to eq(true)
      end

      it "sets the writekey correctly" do
        Rails::Generators.invoke("honeycomb", [writekey])
        require init_file
        expect(Honeycomb.client.libhoney.writekey).to eq(writekey)
      end

      it "sets the dataset to the default" do
        Rails::Generators.invoke("honeycomb", [writekey])
        require init_file
        expect(Honeycomb.client.libhoney.dataset).to eq(default_dataset)
      end

      it "sets the dataset correctly" do
        Rails::Generators.invoke("honeycomb", [writekey, "--dataset", dataset])
        require init_file
        expect(Honeycomb.client.libhoney.dataset).to eq(dataset)
      end
    end
  end
end
