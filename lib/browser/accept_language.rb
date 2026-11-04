# frozen_string_literal: true

module Browser
  class AcceptLanguage
    def self.languages
      @languages ||= YAML.load_file(Browser.root.join("languages.yml"))
    end

    def self.parse(accept_language)
      return [] unless accept_language

      languages = accept_language.split(",")
      languages.map! { |string| new(string.squeeze(" ").strip) }
      languages.reject! { |al| al.quality.zero? }
      languages.sort_by.with_index { |al, idx| [-al.quality, idx] }
    end

    attr_reader :part

    def initialize(part)
      @part = part
    end

    def full
      @full ||= [code, region].compact.join("-")
    end

    def name
      self.class.languages[full] || self.class.languages[code]
    end

    def code
      @code ||= part[/\A([^-;]+)/, 1]&.downcase
    end

    def region
      @region ||= part[/\A(?:.*?)-([^;-]+)/, 1]&.upcase
    end

    def quality
      @quality ||= begin
        Float(quality_value || 1.0)
      rescue ArgumentError
        0.1
      end
    end

    private def quality_value
      qvalue = part[/;q=([\d.]+)/, 1]
      qvalue = "0.0" if /\A0\.0?\z/.match?(qvalue)
      qvalue = qvalue.squeeze(".") if qvalue
      qvalue
    end
  end
end
