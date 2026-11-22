# frozen_string_literal: true

require "delegate"
require "rails"
require_relative "agentry"
require_relative "action_controller"
require_relative "middleware/context/additions"

module Agentry
  class Railtie < Rails::Railtie
    class BrowserConfig < SimpleDelegator
      def method_missing(...) # rubocop:disable Style/MissingRespondToMissing -- Delegator's answers for the target
        Agentry.deprecate("config.browser is deprecated and goes away in 5.0: use config.agentry")
        super
      end
    end

    config.agentry = ActiveSupport::OrderedOptions.new
    config.browser = BrowserConfig.new(config.agentry)
    config.eager_load_namespaces << Agentry

    # An app that assigned config.browser a new object replaced the wrapper: its options become config.agentry.
    def self.adopt_reassigned_browser_config(config)
      return if config.browser.is_a?(BrowserConfig)

      Agentry.deprecate("config.browser is deprecated and goes away in 5.0: use config.agentry")
      config.agentry = config.browser
    end

    config.after_initialize { |app| adopt_reassigned_browser_config(app.config) }

    initializer "agentry" do
      ActiveSupport.on_load(:action_controller) do
        ::ActionController::Base.include(Agentry::ActionController)

        ::ActionController::Metal.include(Agentry::ActionController) if defined?(::ActionController::Metal) # rubocop:disable Layout/LineLength

        Agentry::Middleware::Context.include(
          Agentry::Middleware::Context::Additions
        )
      end
    end
  end
end
