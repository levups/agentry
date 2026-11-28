# frozen_string_literal: true

module Agentry
  module DetectVersion
    # Gem::Version.new and Gem::Version#release keep every version they build in class variables, for the life of
    # the process: a version read from a header must not reach them, or each new one an attacker sends stays.
    # A subclass skips the first; this #release is RubyGems' own without the second.
    class UncachedVersion < Gem::Version
      def release
        return self unless prerelease?

        self.class.new(segments.take_while { |segment| segment.is_a?(Integer) }.join("."))
      end
    end

    private_constant :UncachedVersion

    private def detect_version?(actual_version, expected_version)
      return true unless expected_version
      return false unless actual_version

      expected_version = parse_version(expected_version)
      actual_version = parse_version(actual_version)

      requirement = Cache.requirement(expected_version) { Gem::Requirement.create(expected_version) }
      # RubyGems reads "!" as its source set marker, which compares nothing, and a requirement that can't be read
      # as UTF-8 raises an EncodingError: neither is a requirement a version meets.
      requirement.is_a?(Gem::Requirement) && requirement.satisfied_by?(gem_version(actual_version))
    rescue ArgumentError, EncodingError
      false
    end

    # The last one used: a cached platform asks for the same version on each request, also when Cache keeps none.
    private def gem_version(version)
      string, gem_version = @gem_version
      return gem_version if string == version

      # Frozen: shared by every thread, it computes its segments once, before anyone reads it.
      gem_version = Cache.version(version) do
        version.is_a?(String) ? UncachedVersion.create(version).freeze : UncachedVersion.create(version)
      end
      # An app's browser class may return a Gem::Version, and a frozen browser can't remember.
      kept = version.is_a?(String) && version.bytesize <= Cache::MAX_CACHED_VERSION_BYTES && !frozen?
      @gem_version = [version, gem_version] if kept
      gem_version
    end

    # RubyGems reads a requirement in an ASCII-compatible encoding only: ">= 1" in UTF-16 is still ">= 1". Flattened
    # first: Array#flatten raises an ArgumentError on an array that holds itself.
    private def parse_version(version)
      return version.to_s if version.is_a?(Numeric)
      return version.flatten.map! { |requirement| parse_version(requirement) } if version.is_a?(Array)

      return version unless version.is_a?(String) && !version.encoding.ascii_compatible?

      version.encode(Encoding::UTF_8)
    end
  end
end
