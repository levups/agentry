# frozen_string_literal: true

module Agentry
  class Otter < Base
    def id
      :otter
    end

    def name
      "Otter"
    end

    def full_version
      ua[%r{Otter/([\d.]+)}, 1] || "0.0"
    end

    def match?
      ua.include?("Otter")
    end
  end
end
