# frozen_string_literal: true

require "action_controller/railtie"

module Agentry
  module ActionController
    extend ActiveSupport::Concern

    included do
      helper_method(:agentry, :browser) if respond_to?(:helper_method)
    end

    private def agentry
      @agentry ||= @browser || Agentry.new( # @browser: set by apps and tests written for the browser gem
        request.headers["User-Agent"],
        accept_language: request.headers["Accept-Language"],
        headers: request.env
      )
    end

    private def browser
      Agentry.deprecate("the browser helper is deprecated and goes away in 5.0: call agentry")
      agentry
    end
  end
end
