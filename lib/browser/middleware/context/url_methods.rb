# frozen_string_literal: true

module Browser
  class Middleware
    class Context
      module UrlMethods
        def default_url_options
          config = Rails.configuration

          config.browser.default_url_options ||
            (config.action_mailer.default_url_options if config.respond_to?(:action_mailer)) ||
            {}
        end
      end
    end
  end
end
