# frozen_string_literal: true

module Agentry
  class Middleware
    class Context
      attr_reader :agentry, :request

      def initialize(request)
        @request = request

        @agentry = Agentry.new(
          request.user_agent,
          accept_language: request.env["HTTP_ACCEPT_LANGUAGE"],
          headers: request.env
        )
        @browser = @agentry # browser's name, read by middleware blocks written for it, until 5.0
      end

      def browser
        Agentry.deprecate("browser in an Agentry::Middleware block is deprecated and goes away in 5.0: call agentry")
        @browser
      end

      def redirect_to(path)
        throw :redirected, path.to_s
      end
    end
  end
end
