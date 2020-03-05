# frozen_string_literal: true

if defined?(Honeycomb::Rails)
  require "generators/honeycomb/honeycomb_generator"

  RSpec.describe HoneycombGenerator do
    describe "simple execution" do
      it "creates the initializer file" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            Rails::Generators.invoke("honeycomb", ["writekey"])
            init_file = File.join(dir, "config/initializers/honeycomb.rb")
            expect(File.exist?(init_file)).to eq(true)
          end
        end
      end
    end
  end
end
