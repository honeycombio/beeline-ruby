# frozen_string_literal: true

require "rails/generators"

##
# Generates an intializer for configuring the Honeycomb beeline
#
class HoneycombGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  argument :write_key, required: true, desc: "required"

  class_option :dataset, type: :string, default: "rails"

  gem "honeycomb-beeline"

  desc "Configures honeycomb with your write key"

  def create_initializer_file
    initializer "honeycomb.rb" do
      <<-RUBY.strip_heredoc
        Honeycomb.configure do |config|
          config.write_key = #{write_key.inspect}
          config.dataset = #{options['dataset'].inspect}
          config.notification_events = %w[
            sql.active_record
            render_template.action_view
            render_partial.action_view
            render_collection.action_view
            process_action.action_controller
            send_file.action_controller
            send_data.action_controller
            deliver.action_mailer
          ].freeze
        end
      RUBY
    end
  end
end
