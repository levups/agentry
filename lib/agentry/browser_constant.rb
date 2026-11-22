# frozen_string_literal: true

# Loaded only by the browser/* require paths kept for 4.x: `require "agentry"` alone defines no Browser. Fires at
# boot, so only RUBYOPT=-W:deprecated shows it.
require_relative "agentry"

if Gem.loaded_specs.key?("browser")
  raise LoadError, "agentry's browser/* require paths define Browser, which the browser gem defines too: " \
    "Agentry 4 cannot share a bundle with the browser gem, remove it (or the gem that needs it) from the Gemfile"
end

Browser = Agentry

Agentry.deprecate("require \"browser\" (or browser/*) and the Browser constant are deprecated and go away in 5.0: " \
  "require \"agentry\" and call Agentry")
