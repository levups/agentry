# frozen_string_literal: true

module Agentry
  class Device
    class BlackBerryPlaybook < Base
      def id
        :playbook
      end

      def name
        "BlackBerry Playbook"
      end

      def match?
        ua.match?(/PlayBook.*?RIM Tablet/)
      end
    end
  end
end
