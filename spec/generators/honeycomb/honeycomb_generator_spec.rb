# frozen_string_literal: true

if defined?(Honeycomb::Rails)
  require "generators/honeycomb/honeycomb_generator"

  RSpec.describe HoneycombGenerator do
    describe "simple execution" do
      let(:name) { "honeycomb" }
      let(:write_key) { "generator_write_key" }
      let(:dataset) { "generator_dataset" }
      let(:init_file) { File.join(@dir, "config/initializers/honeycomb.rb") }
      let(:config) { Honeycomb::Configuration.new }

      around(:example) do |example|
        Dir.mktmpdir do |dir|
          Dir.chdir dir do
            @dir = dir
            example.run
          end
        end
      end

      it "creates the initializer file" do
        Rails::Generators.invoke(name, [write_key])
        expect(File.exist?(init_file)).to eq(true)
      end

      describe "configuring honeycomb" do
        before(:each) do
          honeycomb = class_double("Honeycomb")
                      .as_stubbed_const(transfer_nested_constants: true)
          expect(honeycomb).to receive(:configure) do |&block|
            block.call config
          end
        end

        it "sets the writekey correctly" do
          Rails::Generators.invoke(name, [write_key])
          require init_file
          expect(config.write_key).to eq(write_key)
        end

        it "sets the dataset to a default" do
          Rails::Generators.invoke(name, [write_key])
          require init_file
          expect(config.dataset).not_to be_empty
        end

        it "sets the dataset correctly" do
          Rails::Generators.invoke(name, [write_key, "--dataset", dataset])
          require init_file
          expect(config.dataset).to eq(dataset)
        end

        it "sets the notification events" do
          Rails::Generators.invoke(name, [write_key])
          require init_file
          expect(config.notification_events).not_to be_empty
        end

        describe "the presend hook" do
          let(:presend_hook) { config.presend_hook }

          before(:each) do
            Rails::Generators.invoke(name, [write_key])
            require init_file
            presend_hook.call(data)
          end

          describe "redis sanitizing" do
            let(:data) do
              {
                "name" => "redis",
                "redis.command" => "SET PII",
              }
            end

            it "removes the PII from the redis command" do
              expect(data).to include("redis.command" => "SET")
            end
          end

          describe "redis sanitizing with unexpected data" do
            let(:data) do
              {
                "name" => "redis",
                "redis.command" => 1,
              }
            end

            it "removes the PII from the redis command" do
              expect(data).to include("redis.command" => 1)
            end
          end

          describe "sql.active_record sanitizing" do
            let(:data) do
              {
                "name" => "sql.active_record",
                "sql.active_record.binds" => true,
                "sql.active_record.type_casted_binds" => true,
              }
            end

            it "filters out the sql.active_record.binds" do
              expect(data).not_to include("sql.active_record.binds")
            end

            it "filters out the sql.active_record.binds" do
              expect(data).not_to include("sql.active_record.type_casted_binds")
            end
          end
        end
      end
    end
  end
end
