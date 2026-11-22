# frozen_string_literal: true

require "action_controller/railtie"

module Agentry
  module ActionController
    extend ActiveSupport::Concern

    included do
      helper_method(:agentry, :browser) if respond_to?(:helper_method)
    end

    private def agentry
      return @agentry if @agentry

      @agentry = Agentry.new(
        request.headers["User-Agent"],
        accept_language: request.headers["Accept-Language"],
        headers: request.env
      )
      @browser ||= @agentry # browser's name, read by views written for it, until 5.0
      @agentry
    end

    # Fills and honours @browser, as browser's helper did: apps and tests set it to fake a device.
    private def browser
      Agentry.deprecate("the browser helper is deprecated and goes away in 5.0: call agentry")
      @browser ||= agentry
    end
  end
end
