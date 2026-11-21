# frozen_string_literal: true

# Loaded only by the browser/* require paths kept for 4.x: `require "agentry"` alone defines no Browser.
if Gem.loaded_specs.key?("browser")
  raise LoadError, "agentry's browser/* require paths define Browser, which the browser gem defines too: " \
    "require \"agentry\" and call Agentry instead, or remove gem \"browser\" from the Gemfile"
end

Browser = Agentry

Agentry.deprecate("require \"browser\" (or browser/*) and the Browser constant are deprecated and go away in 5.0: " \
  "require \"agentry\" and call Agentry")
