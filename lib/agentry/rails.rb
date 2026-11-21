# frozen_string_literal: true

require "rails"
require_relative "action_controller"
require_relative "middleware/context/additions"

module Agentry
  class Railtie < Rails::Railtie
    config.agentry = ActiveSupport::OrderedOptions.new
    config.browser = config.agentry
    config.eager_load_namespaces << Agentry

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
