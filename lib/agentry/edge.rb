# frozen_string_literal: true

module Agentry
  class Edge < InternetExplorer
    def id
      :edge
    end

    def name
      "Microsoft Edge"
    end

    def full_version
      ua[%r{(?:Edge|Edg|EdgiOS|EdgA)/([\d.]+)}, 1] || super
    end

    def match?
      ua.match?(%r{((?:Edge|Edg|EdgiOS|EdgA)/[\d.]+|Trident/8)})
    end

    def chromium_based?
      match? && ua.match?(/\bEdg\b/)
    end
  end
end
